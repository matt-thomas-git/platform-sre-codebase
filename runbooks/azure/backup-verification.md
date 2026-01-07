# Azure Backup Verification Runbook

## Overview
This runbook provides procedures for verifying Azure Backup configurations and monitoring backup health for VMs and SQL databases.

**Last Updated:** 2026-01-04  
**Applies To:** Azure VMs, Azure SQL Databases, Recovery Services Vaults

---

## Prerequisites

- Azure subscription access
- Reader access to Recovery Services Vaults
- Azure PowerShell module installed
- Appropriate RBAC permissions

---

## Recovery Services Vault Setup

### Standard Configuration

**Vault Settings:**
- **Geo-Redundant Storage (GRS):** Enabled for production
- **Soft Delete:** Enabled (14-day retention)
- **Cross-Region Restore:** Enabled for critical workloads
- **Private Endpoints:** Configured for secure access

### Backup Policies

#### VM Backup Policy (Production)
```
Policy Name: VM-Production-Daily
Frequency: Daily at 2:00 AM UTC
Retention:
  - Daily: 30 days
  - Weekly: 12 weeks
  - Monthly: 12 months
  - Yearly: 7 years
```

#### SQL Database Backup Policy
```
Policy Name: SQL-Production-Comprehensive
Full Backup: Weekly (Sunday 2:00 AM)
Differential: Daily (except Sunday)
Log Backup: Every 15 minutes
Retention:
  - Full: 35 days
  - Differential: 35 days
  - Log: 35 days
```

---

## Verification Procedures

### 1. Check Backup Status (PowerShell)

```powershell
<#
.SYNOPSIS
    Verify backup status for all VMs in a Recovery Services Vault
#>

# Connect to Azure
Connect-AzAccount

# Set context
$vaultName = "rsv-prod-eastus2-01"
$resourceGroup = "rg-backup-prod"

# Get vault
$vault = Get-AzRecoveryServicesVault -Name $vaultName -ResourceGroupName $resourceGroup
Set-AzRecoveryServicesVaultContext -Vault $vault

# Get all backup items
$backupItems = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM

# Check status
$results = @()
foreach ($item in $backupItems) {
    $lastBackup = Get-AzRecoveryServicesBackupRecoveryPoint -Item $item -StartDate (Get-Date).AddDays(-7) | 
                  Select-Object -First 1
    
    $results += [PSCustomObject]@{
        VMName = $item.Name
        ProtectionState = $item.ProtectionState
        LastBackupTime = $lastBackup.RecoveryPointTime
        HealthStatus = $item.HealthStatus
        LastBackupStatus = $item.LastBackupStatus
    }
}

# Display results
$results | Format-Table -AutoSize

# Alert on failures
$failures = $results | Where-Object { $_.LastBackupStatus -ne "Completed" }
if ($failures) {
    Write-Warning "⚠ Backup failures detected:"
    $failures | Format-Table -AutoSize
}
```

### 2. Verify SQL Database Backups

```powershell
<#
.SYNOPSIS
    Check SQL database backup status
#>

# Get SQL backup items
$sqlBackups = Get-AzRecoveryServicesBackupItem `
    -BackupManagementType AzureWorkload `
    -WorkloadType MSSQL

$sqlResults = @()
foreach ($db in $sqlBackups) {
    $recoveryPoints = Get-AzRecoveryServicesBackupRecoveryPoint `
        -Item $db `
        -StartDate (Get-Date).AddDays(-1)
    
    $sqlResults += [PSCustomObject]@{
        DatabaseName = $db.FriendlyName
        ServerName = $db.ServerName
        ProtectionState = $db.ProtectionState
        LastRecoveryPoint = ($recoveryPoints | Select-Object -First 1).RecoveryPointTime
        RecoveryPointCount = $recoveryPoints.Count
        HealthStatus = $db.HealthStatus
    }
}

$sqlResults | Format-Table -AutoSize
```

### 3. Check Backup Job History

```powershell
<#
.SYNOPSIS
    Review recent backup jobs for failures
#>

# Get jobs from last 24 hours
$startDate = (Get-Date).AddDays(-1)
$jobs = Get-AzRecoveryServicesBackupJob -From $startDate

# Summarize by status
$jobSummary = $jobs | Group-Object Status | Select-Object Name, Count

Write-Host "Backup Job Summary (Last 24 Hours):" -ForegroundColor Cyan
$jobSummary | Format-Table -AutoSize

# Show failed jobs
$failedJobs = $jobs | Where-Object { $_.Status -eq "Failed" }
if ($failedJobs) {
    Write-Host "`n⚠ Failed Jobs:" -ForegroundColor Red
    $failedJobs | Select-Object WorkloadName, Operation, Status, StartTime, ErrorDetails | 
                  Format-Table -AutoSize
}
```

---

## Common Issues and Resolutions

### Issue 1: Backup Job Failing

**Symptoms:**
- Backup jobs show "Failed" status
- Error: "UserErrorVmProvisioningStateFailed"

**Resolution:**
1. Verify VM is running and accessible
2. Check VM agent status:
   ```powershell
   $vm = Get-AzVM -ResourceGroupName "rg-prod" -Name "vm-app-01" -Status
   $vm.VMAgent.Statuses
   ```
3. If agent is not ready, restart VM
4. Retry backup job manually

### Issue 2: SQL Backup Failing

**Symptoms:**
- SQL backup shows "Failed" status
- Error: "UserErrorSQLNoSysadminMembership"

**Resolution:**
1. Verify backup service has sysadmin rights on SQL instance
2. Run discovery again:
   ```powershell
   # Re-register SQL instance
   Register-AzRecoveryServicesBackupContainer `
       -ResourceGroupName "rg-sql-prod" `
       -VaultId $vault.ID `
       -WorkloadType MSSQL
   ```
3. Verify SQL Server service is running
4. Check SQL error logs for additional details

### Issue 3: Backup Taking Too Long

**Symptoms:**
- Backup jobs running for extended periods
- Timeout errors

**Resolution:**
1. Check VM disk performance
2. Verify network connectivity to vault
3. Consider:
   - Incremental backups instead of full
   - Adjusting backup window
   - Enabling instant restore (snapshot tier)

### Issue 4: Restore Point Missing

**Symptoms:**
- Expected restore point not available
- Gaps in backup history

**Resolution:**
1. Check backup job history for that date
2. Verify backup policy was active
3. Check for VM state changes (deallocated, stopped)
4. Review Activity Log for vault operations

---

## Monitoring and Alerting

### Azure Monitor Alerts

**Recommended Alerts:**

1. **Backup Failure Alert**
   ```
   Resource: Recovery Services Vault
   Signal: Backup Health Event
   Condition: When backup fails
   Action: Email to ops team
   ```

2. **No Backup in 24 Hours**
   ```
   Resource: Recovery Services Vault
   Signal: Backup Health Event
   Condition: No successful backup in 24 hours
   Action: Email + SMS to on-call
   ```

3. **Vault Storage Threshold**
   ```
   Resource: Recovery Services Vault
   Signal: Backup Storage Size
   Condition: > 80% of quota
   Action: Email to platform team
   ```

### PowerShell Monitoring Script

```powershell
<#
.SYNOPSIS
    Daily backup health check script
.DESCRIPTION
    Runs daily to verify all backups completed successfully
#>

param(
    [string]$VaultName = "rsv-prod-eastus2-01",
    [string]$ResourceGroup = "rg-backup-prod",
    [string]$EmailTo = "platform-team@example.com"
)

# Connect and set context
Connect-AzAccount -Identity
$vault = Get-AzRecoveryServicesVault -Name $VaultName -ResourceGroupName $ResourceGroup
Set-AzRecoveryServicesVaultContext -Vault $vault

# Check last 24 hours
$startDate = (Get-Date).AddDays(-1)
$jobs = Get-AzRecoveryServicesBackupJob -From $startDate

# Analyze results
$failed = $jobs | Where-Object { $_.Status -eq "Failed" }
$inProgress = $jobs | Where-Object { $_.Status -eq "InProgress" }
$completed = $jobs | Where-Object { $_.Status -eq "Completed" }

# Build report
$report = @"
Azure Backup Daily Health Report
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Vault: $VaultName

Summary:
- Completed: $($completed.Count)
- Failed: $($failed.Count)
- In Progress: $($inProgress.Count)

$(if ($failed.Count -gt 0) {
    "FAILED JOBS:`n" + ($failed | Select-Object WorkloadName, Operation, ErrorDetails | Out-String)
})

$(if ($inProgress.Count -gt 0) {
    "IN PROGRESS:`n" + ($inProgress | Select-Object WorkloadName, Operation, StartTime | Out-String)
})
"@

Write-Output $report

# Send email if failures
if ($failed.Count -gt 0) {
    # Email logic here (requires SendGrid or similar)
    Write-Warning "Backup failures detected - alert sent"
}
```

---

## Backup Testing Procedures

### Monthly Restore Test

**Purpose:** Verify backups are restorable

**Procedure:**
1. Select a random VM from production
2. Restore to test resource group
3. Verify VM boots and is accessible
4. Validate application functionality
5. Document results
6. Delete test VM

**PowerShell Example:**
```powershell
# Get latest recovery point
$backupItem = Get-AzRecoveryServicesBackupItem `
    -BackupManagementType AzureVM `
    -WorkloadType AzureVM `
    -Name "vm-app-01"

$recoveryPoint = Get-AzRecoveryServicesBackupRecoveryPoint `
    -Item $backupItem | 
    Select-Object -First 1

# Restore to test RG
$restoreConfig = Get-AzRecoveryServicesBackupWorkloadRecoveryConfig `
    -RecoveryPoint $recoveryPoint `
    -TargetResourceGroupName "rg-backup-test" `
    -RestoreAsUnmanagedDisks

Restore-AzRecoveryServicesBackupItem `
    -WLRecoveryConfig $restoreConfig
```

---

## Best Practices

### 1. Backup Strategy
- ✅ Use GRS for production workloads
- ✅ Enable soft delete (protection against accidental deletion)
- ✅ Implement 3-2-1 rule where possible (3 copies, 2 media types, 1 offsite)
- ✅ Tag backup items for easy identification

### 2. Retention Policies
- ✅ Align with business requirements and compliance
- ✅ Balance cost vs. recovery needs
- ✅ Document retention decisions

### 3. Testing
- ✅ Test restores monthly
- ✅ Document restore procedures
- ✅ Measure RTO (Recovery Time Objective)
- ✅ Verify RPO (Recovery Point Objective) meets requirements

### 4. Monitoring
- ✅ Set up alerts for backup failures
- ✅ Review backup reports weekly
- ✅ Monitor vault capacity
- ✅ Track backup job duration trends

### 5. Security
- ✅ Use private endpoints for vault access
- ✅ Enable MFA for restore operations
- ✅ Implement RBAC for backup operations
- ✅ Audit backup and restore activities

---

## Compliance and Reporting

### Monthly Backup Report

**Required Information:**
- Total VMs protected
- Total SQL databases protected
- Backup success rate
- Failed backup details
- Storage consumption
- Restore tests performed

### Audit Questions

1. Are all production VMs backed up?
2. Are backup policies compliant with retention requirements?
3. Have restore tests been performed this month?
4. Are there any backup failures requiring attention?
5. Is vault capacity adequate?

---

## Emergency Procedures

### Critical VM Restore

**When:** Production VM is corrupted or lost

**Steps:**
1. Identify latest good recovery point
2. Notify stakeholders of restore operation
3. Initiate restore to production or staging
4. Verify VM functionality
5. Update DNS/load balancer if needed
6. Document incident

### SQL Database Restore

**When:** Database corruption or data loss

**Steps:**
1. Determine point-in-time for restore
2. Restore to alternate location first (if possible)
3. Verify data integrity
4. Coordinate with application team
5. Perform cutover during maintenance window
6. Document recovery

---

## Related Documentation

- [Azure Backup Documentation](https://docs.microsoft.com/azure/backup/)
- [SQL Server Backup Best Practices](https://docs.microsoft.com/sql/relational-databases/backup-restore/)
- [Recovery Services Vault Overview](https://docs.microsoft.com/azure/backup/backup-azure-recovery-services-vault-overview)

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-04 | 1.0 | Initial runbook creation |
