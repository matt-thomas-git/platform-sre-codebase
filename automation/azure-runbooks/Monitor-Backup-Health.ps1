<#
.SYNOPSIS
    Azure Automation Runbook to monitor backup health across Recovery Services Vaults.

.DESCRIPTION
    This runbook checks backup status for all protected items in specified Recovery Services Vaults
    and reports on failures, missing backups, and overall health. Designed to run as a scheduled
    Azure Automation Runbook using Managed Identity.

.PARAMETER VaultNames
    Array of Recovery Services Vault names to monitor. If not specified, monitors all vaults in subscription.

.PARAMETER AlertThresholdHours
    Number of hours since last successful backup before alerting. Default: 25 hours.

.PARAMETER SendEmail
    If true, sends email notification for failures (requires additional configuration).

.EXAMPLE
    # Monitor specific vaults
    .\Monitor-Backup-Health.ps1 -VaultNames @("rsv-prod-eastus2-01", "rsv-prod-westeurope-01")

.EXAMPLE
    # Monitor all vaults with custom threshold
    .\Monitor-Backup-Health.ps1 -AlertThresholdHours 48

.NOTES
    Author: Platform Engineering Team
    Date: 2026-01-04
    Version: 1.0
    
    Requirements:
    - Azure Automation Account with Managed Identity enabled
    - Managed Identity must have "Backup Reader" role on Recovery Services Vaults
    - Az.RecoveryServices module imported in Automation Account
#>

param(
    [Parameter(Mandatory = $false)]
    [string[]]$VaultNames = @(),
    
    [Parameter(Mandatory = $false)]
    [int]$AlertThresholdHours = 25,
    
    [Parameter(Mandatory = $false)]
    [bool]$SendEmail = $false
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Initialize results
$results = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    VaultsChecked = 0
    TotalProtectedItems = 0
    HealthyItems = 0
    WarningItems = 0
    CriticalItems = 0
    FailedJobs = @()
    MissingBackups = @()
    Summary = ""
}

$startTime = Get-Date

try {
    Write-Output "========================================="
    Write-Output "Azure Backup Health Monitor"
    Write-Output "========================================="
    Write-Output "Timestamp: $($results.Timestamp)"
    Write-Output "Alert Threshold: $AlertThresholdHours hours"
    Write-Output ""
    
    # Connect to Azure using Managed Identity
    Write-Output "Connecting to Azure using Managed Identity..."
    try {
        $connection = Connect-AzAccount -Identity -ErrorAction Stop
        Write-Output "✓ Successfully connected to Azure"
        Write-Output "  Subscription: $($connection.Context.Subscription.Name)"
        Write-Output ""
    }
    catch {
        throw "Failed to connect to Azure using Managed Identity. Error: $($_.Exception.Message)"
    }
    
    # Get vaults to monitor
    if ($VaultNames.Count -eq 0) {
        Write-Output "Discovering all Recovery Services Vaults in subscription..."
        $vaults = Get-AzRecoveryServicesVault
        Write-Output "✓ Found $($vaults.Count) vault(s)"
    }
    else {
        Write-Output "Monitoring specified vaults: $($VaultNames -join ', ')"
        $vaults = @()
        foreach ($vaultName in $VaultNames) {
            try {
                $vault = Get-AzRecoveryServicesVault | Where-Object { $_.Name -eq $vaultName }
                if ($vault) {
                    $vaults += $vault
                }
                else {
                    Write-Warning "Vault '$vaultName' not found"
                }
            }
            catch {
                Write-Warning "Error retrieving vault '$vaultName': $($_.Exception.Message)"
            }
        }
    }
    
    if ($vaults.Count -eq 0) {
        Write-Warning "No vaults found to monitor"
        $results.Summary = "No vaults found"
        return
    }
    
    $results.VaultsChecked = $vaults.Count
    Write-Output ""
    
    # Check each vault
    foreach ($vault in $vaults) {
        Write-Output "========================================="
        Write-Output "Vault: $($vault.Name)"
        Write-Output "Location: $($vault.Location)"
        Write-Output "Resource Group: $($vault.ResourceGroupName)"
        Write-Output "========================================="
        
        # Set vault context
        Set-AzRecoveryServicesVaultContext -Vault $vault
        
        # Get backup items (VMs)
        Write-Output "Checking Azure VM backups..."
        try {
            $vmBackupItems = Get-AzRecoveryServicesBackupItem `
                -BackupManagementType AzureVM `
                -WorkloadType AzureVM `
                -VaultId $vault.ID
            
            Write-Output "  Found $($vmBackupItems.Count) protected VM(s)"
            
            foreach ($item in $vmBackupItems) {
                $results.TotalProtectedItems++
                
                # Get latest recovery point
                $recoveryPoints = Get-AzRecoveryServicesBackupRecoveryPoint `
                    -Item $item `
                    -StartDate (Get-Date).AddDays(-2) `
                    -VaultId $vault.ID
                
                $latestRecoveryPoint = $recoveryPoints | Select-Object -First 1
                
                # Calculate hours since last backup
                $hoursSinceBackup = if ($latestRecoveryPoint) {
                    ((Get-Date) - $latestRecoveryPoint.RecoveryPointTime).TotalHours
                } else {
                    999
                }
                
                # Determine health status
                $status = if ($hoursSinceBackup -gt $AlertThresholdHours) {
                    $results.CriticalItems++
                    "CRITICAL"
                } elseif ($item.LastBackupStatus -ne "Completed") {
                    $results.WarningItems++
                    "WARNING"
                } else {
                    $results.HealthyItems++
                    "HEALTHY"
                }
                
                # Log issues
                if ($status -ne "HEALTHY") {
                    $issue = [PSCustomObject]@{
                        Vault = $vault.Name
                        ItemName = $item.Name
                        ItemType = "Azure VM"
                        Status = $status
                        LastBackupStatus = $item.LastBackupStatus
                        LastBackupTime = if ($latestRecoveryPoint) { $latestRecoveryPoint.RecoveryPointTime } else { "Never" }
                        HoursSinceBackup = [math]::Round($hoursSinceBackup, 1)
                        HealthStatus = $item.HealthStatus
                    }
                    
                    if ($hoursSinceBackup -gt $AlertThresholdHours) {
                        $results.MissingBackups += $issue
                    }
                    
                    Write-Output "  ⚠ $($item.Name): $status - Last backup: $($issue.LastBackupTime) ($($issue.HoursSinceBackup)h ago)"
                }
            }
        }
        catch {
            Write-Warning "Error checking VM backups: $($_.Exception.Message)"
        }
        
        # Get SQL backup items
        Write-Output "Checking SQL Server backups..."
        try {
            $sqlBackupItems = Get-AzRecoveryServicesBackupItem `
                -BackupManagementType AzureWorkload `
                -WorkloadType MSSQL `
                -VaultId $vault.ID
            
            Write-Output "  Found $($sqlBackupItems.Count) protected SQL database(s)"
            
            foreach ($item in $sqlBackupItems) {
                $results.TotalProtectedItems++
                
                # Get latest recovery point
                $recoveryPoints = Get-AzRecoveryServicesBackupRecoveryPoint `
                    -Item $item `
                    -StartDate (Get-Date).AddDays(-2) `
                    -VaultId $vault.ID
                
                $latestRecoveryPoint = $recoveryPoints | Select-Object -First 1
                
                # Calculate hours since last backup
                $hoursSinceBackup = if ($latestRecoveryPoint) {
                    ((Get-Date) - $latestRecoveryPoint.RecoveryPointTime).TotalHours
                } else {
                    999
                }
                
                # Determine health status
                $status = if ($hoursSinceBackup -gt $AlertThresholdHours) {
                    $results.CriticalItems++
                    "CRITICAL"
                } elseif ($item.LastBackupStatus -ne "Completed") {
                    $results.WarningItems++
                    "WARNING"
                } else {
                    $results.HealthyItems++
                    "HEALTHY"
                }
                
                # Log issues
                if ($status -ne "HEALTHY") {
                    $issue = [PSCustomObject]@{
                        Vault = $vault.Name
                        ItemName = $item.FriendlyName
                        ItemType = "SQL Database"
                        Status = $status
                        LastBackupStatus = $item.LastBackupStatus
                        LastBackupTime = if ($latestRecoveryPoint) { $latestRecoveryPoint.RecoveryPointTime } else { "Never" }
                        HoursSinceBackup = [math]::Round($hoursSinceBackup, 1)
                        HealthStatus = $item.HealthStatus
                    }
                    
                    if ($hoursSinceBackup -gt $AlertThresholdHours) {
                        $results.MissingBackups += $issue
                    }
                    
                    Write-Output "  ⚠ $($item.FriendlyName): $status - Last backup: $($issue.LastBackupTime) ($($issue.HoursSinceBackup)h ago)"
                }
            }
        }
        catch {
            Write-Warning "Error checking SQL backups: $($_.Exception.Message)"
        }
        
        # Check recent backup jobs
        Write-Output "Checking recent backup jobs (last 24 hours)..."
        try {
            $jobs = Get-AzRecoveryServicesBackupJob `
                -From (Get-Date).AddDays(-1) `
                -VaultId $vault.ID
            
            $failedJobs = $jobs | Where-Object { $_.Status -eq "Failed" }
            
            if ($failedJobs.Count -gt 0) {
                Write-Output "  ⚠ Found $($failedJobs.Count) failed job(s)"
                
                foreach ($job in $failedJobs) {
                    $results.FailedJobs += [PSCustomObject]@{
                        Vault = $vault.Name
                        WorkloadName = $job.WorkloadName
                        Operation = $job.Operation
                        Status = $job.Status
                        StartTime = $job.StartTime
                        ErrorDetails = $job.ErrorDetails.ErrorMessage
                    }
                    
                    Write-Output "    - $($job.WorkloadName): $($job.Operation) failed at $($job.StartTime)"
                }
            }
            else {
                Write-Output "  ✓ No failed jobs in last 24 hours"
            }
        }
        catch {
            Write-Warning "Error checking backup jobs: $($_.Exception.Message)"
        }
        
        Write-Output ""
    }
    
}
catch {
    Write-Output ""
    Write-Output "========================================="
    Write-Output "ERROR"
    Write-Output "========================================="
    Write-Output "An error occurred: $($_.Exception.Message)"
    Write-Output ""
    Write-Output "Stack Trace:"
    Write-Output $_.ScriptStackTrace
    
    throw
}
finally {
    # Calculate duration
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    # Build summary
    $healthPercentage = if ($results.TotalProtectedItems -gt 0) {
        [math]::Round(($results.HealthyItems / $results.TotalProtectedItems) * 100, 1)
    } else {
        0
    }
    
    $results.Summary = "Checked $($results.VaultsChecked) vault(s), $($results.TotalProtectedItems) protected item(s). Health: $healthPercentage% ($($results.HealthyItems) healthy, $($results.WarningItems) warnings, $($results.CriticalItems) critical)"
    
    # Output summary
    Write-Output ""
    Write-Output "========================================="
    Write-Output "SUMMARY"
    Write-Output "========================================="
    Write-Output "Vaults Checked: $($results.VaultsChecked)"
    Write-Output "Total Protected Items: $($results.TotalProtectedItems)"
    Write-Output "Healthy: $($results.HealthyItems) ($healthPercentage%)"
    Write-Output "Warnings: $($results.WarningItems)"
    Write-Output "Critical: $($results.CriticalItems)"
    Write-Output "Failed Jobs (24h): $($results.FailedJobs.Count)"
    Write-Output "Missing Backups: $($results.MissingBackups.Count)"
    Write-Output "Duration: $($duration.Minutes)m $($duration.Seconds)s"
    Write-Output "========================================="
    
    # Show critical issues
    if ($results.MissingBackups.Count -gt 0) {
        Write-Output ""
        Write-Output "CRITICAL: Missing or Overdue Backups"
        Write-Output "========================================="
        $results.MissingBackups | Format-Table -Property Vault, ItemName, ItemType, LastBackupTime, HoursSinceBackup -AutoSize
    }
    
    if ($results.FailedJobs.Count -gt 0) {
        Write-Output ""
        Write-Output "FAILED JOBS (Last 24 Hours)"
        Write-Output "========================================="
        $results.FailedJobs | Format-Table -Property Vault, WorkloadName, Operation, StartTime -AutoSize
    }
    
    # Overall status
    Write-Output ""
    if ($results.CriticalItems -eq 0 -and $results.FailedJobs.Count -eq 0) {
        Write-Output "✓ Overall Status: HEALTHY"
    }
    elseif ($results.CriticalItems -gt 0) {
        Write-Output "✗ Overall Status: CRITICAL - Immediate attention required"
    }
    else {
        Write-Output "⚠ Overall Status: WARNING - Review recommended"
    }
    
    # Output as JSON for programmatic consumption
    Write-Output ""
    Write-Output "JSON Output:"
    Write-Output ($results | ConvertTo-Json -Compress -Depth 3)
}
