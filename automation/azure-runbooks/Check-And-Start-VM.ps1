<#
.SYNOPSIS
    Azure Automation Runbook to check VM power state and start if deallocated.

.DESCRIPTION
    This runbook checks the power state of an Azure VM and automatically starts it
    if it's in a deallocated state. Designed to run as an Azure Automation Runbook
    using a Managed Identity for authentication.

.PARAMETER ResourceGroupName
    The name of the resource group containing the VM.

.PARAMETER VMName
    The name of the virtual machine to check and start.

.PARAMETER SendNotification
    Optional. If true, sends notification on state changes (requires additional setup).

.EXAMPLE
    # Run manually with parameters
    .\Check-And-Start-VM.ps1 -ResourceGroupName "rg-production-01" -VMName "vm-app-01"

.NOTES
    Author: Platform Engineering Team
    Date: 2026-01-04
    Version: 2.0
    
    Requirements:
    - Azure Automation Account with Managed Identity enabled
    - Managed Identity must have "Virtual Machine Contributor" role on target VM/RG
    - Az.Accounts and Az.Compute modules imported in Automation Account
    
    Power States:
    - PowerState/running: VM is running
    - PowerState/deallocated: VM is stopped and deallocated
    - PowerState/stopped: VM is stopped but not deallocated
    - PowerState/starting: VM is in the process of starting
    - PowerState/stopping: VM is in the process of stopping
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$VMName,
    
    [Parameter(Mandatory = $false)]
    [bool]$SendNotification = $false
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Initialize result object for structured output
$result = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    ResourceGroup = $ResourceGroupName
    VMName = $VMName
    InitialPowerState = $null
    FinalPowerState = $null
    ActionTaken = "None"
    Success = $false
    Message = ""
    Duration = $null
}

$startTime = Get-Date

try {
    Write-Output "========================================="
    Write-Output "Azure VM Auto-Start Runbook"
    Write-Output "========================================="
    Write-Output "Timestamp: $($result.Timestamp)"
    Write-Output "Resource Group: $ResourceGroupName"
    Write-Output "VM Name: $VMName"
    Write-Output ""
    
    # Connect to Azure using Managed Identity
    Write-Output "Connecting to Azure using Managed Identity..."
    try {
        $connection = Connect-AzAccount -Identity -ErrorAction Stop
        Write-Output "✓ Successfully connected to Azure"
        Write-Output "  Subscription: $($connection.Context.Subscription.Name)"
        Write-Output "  Tenant: $($connection.Context.Tenant.Id)"
        Write-Output ""
    }
    catch {
        throw "Failed to connect to Azure using Managed Identity. Ensure Managed Identity is enabled and has proper permissions. Error: $($_.Exception.Message)"
    }
    
    # Get VM status
    Write-Output "Retrieving VM status..."
    try {
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status -ErrorAction Stop
        Write-Output "✓ Successfully retrieved VM information"
    }
    catch {
        throw "Failed to retrieve VM '$VMName' in resource group '$ResourceGroupName'. Verify the VM exists and Managed Identity has 'Reader' permissions. Error: $($_.Exception.Message)"
    }
    
    # Extract power state
    $powerState = ($vm.Statuses | Where-Object {$_.Code -like "PowerState/*"}).Code
    $result.InitialPowerState = $powerState
    
    Write-Output ""
    Write-Output "VM Information:"
    Write-Output "  Name: $($vm.Name)"
    Write-Output "  Location: $($vm.Location)"
    Write-Output "  VM Size: $($vm.HardwareProfile.VmSize)"
    Write-Output "  Power State: $powerState"
    Write-Output ""
    
    # Check power state and take action
    switch ($powerState) {
        "PowerState/deallocated" {
            Write-Output "⚠ VM is deallocated. Attempting to start..."
            $result.ActionTaken = "Start VM"
            
            try {
                # Start the VM
                $startOperation = Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -NoWait:$false -ErrorAction Stop
                
                if ($startOperation.Status -eq "Succeeded") {
                    Write-Output "✓ VM started successfully"
                    $result.Success = $true
                    $result.Message = "VM was deallocated and has been started successfully"
                    
                    # Get updated status
                    Start-Sleep -Seconds 5
                    $vmUpdated = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
                    $result.FinalPowerState = ($vmUpdated.Statuses | Where-Object {$_.Code -like "PowerState/*"}).Code
                    Write-Output "  Final Power State: $($result.FinalPowerState)"
                }
                else {
                    Write-Output "⚠ VM start operation completed with status: $($startOperation.Status)"
                    $result.Success = $false
                    $result.Message = "VM start operation completed with unexpected status: $($startOperation.Status)"
                    $result.FinalPowerState = $powerState
                }
            }
            catch {
                Write-Output "✗ Failed to start VM: $($_.Exception.Message)"
                $result.Success = $false
                $result.Message = "Failed to start VM: $($_.Exception.Message)"
                $result.FinalPowerState = $powerState
                throw
            }
        }
        
        "PowerState/running" {
            Write-Output "✓ VM is already running. No action needed."
            $result.ActionTaken = "None - Already Running"
            $result.Success = $true
            $result.Message = "VM is running normally"
            $result.FinalPowerState = $powerState
        }
        
        "PowerState/stopped" {
            Write-Output "⚠ VM is stopped (but not deallocated). Starting VM..."
            $result.ActionTaken = "Start VM (from stopped state)"
            
            try {
                $startOperation = Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -NoWait:$false -ErrorAction Stop
                
                if ($startOperation.Status -eq "Succeeded") {
                    Write-Output "✓ VM started successfully"
                    $result.Success = $true
                    $result.Message = "VM was stopped and has been started successfully"
                    
                    # Get updated status
                    Start-Sleep -Seconds 5
                    $vmUpdated = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
                    $result.FinalPowerState = ($vmUpdated.Statuses | Where-Object {$_.Code -like "PowerState/*"}).Code
                    Write-Output "  Final Power State: $($result.FinalPowerState)"
                }
                else {
                    $result.Success = $false
                    $result.Message = "VM start operation completed with unexpected status: $($startOperation.Status)"
                    $result.FinalPowerState = $powerState
                }
            }
            catch {
                Write-Output "✗ Failed to start VM: $($_.Exception.Message)"
                $result.Success = $false
                $result.Message = "Failed to start VM: $($_.Exception.Message)"
                $result.FinalPowerState = $powerState
                throw
            }
        }
        
        "PowerState/starting" {
            Write-Output "ℹ VM is currently starting. No action needed."
            $result.ActionTaken = "None - Already Starting"
            $result.Success = $true
            $result.Message = "VM is already in the process of starting"
            $result.FinalPowerState = $powerState
        }
        
        "PowerState/stopping" {
            Write-Output "⚠ VM is currently stopping. Waiting for stop to complete before starting..."
            $result.ActionTaken = "Wait and Start"
            
            # Wait for VM to finish stopping
            $maxWaitTime = 300 # 5 minutes
            $waitInterval = 10
            $elapsedTime = 0
            
            while ($elapsedTime -lt $maxWaitTime) {
                Start-Sleep -Seconds $waitInterval
                $elapsedTime += $waitInterval
                
                $vmCheck = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
                $currentState = ($vmCheck.Statuses | Where-Object {$_.Code -like "PowerState/*"}).Code
                
                Write-Output "  Waiting... Current state: $currentState (${elapsedTime}s elapsed)"
                
                if ($currentState -eq "PowerState/deallocated" -or $currentState -eq "PowerState/stopped") {
                    Write-Output "✓ VM has stopped. Now starting..."
                    $startOperation = Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -NoWait:$false
                    
                    if ($startOperation.Status -eq "Succeeded") {
                        $result.Success = $true
                        $result.Message = "VM was stopping, waited for completion, then started successfully"
                        $result.FinalPowerState = "PowerState/running"
                    }
                    break
                }
            }
            
            if ($elapsedTime -ge $maxWaitTime) {
                $result.Success = $false
                $result.Message = "Timeout waiting for VM to stop"
                $result.FinalPowerState = $currentState
            }
        }
        
        default {
            Write-Output "⚠ Unknown power state: $powerState"
            $result.ActionTaken = "None - Unknown State"
            $result.Success = $false
            $result.Message = "VM is in an unknown power state: $powerState"
            $result.FinalPowerState = $powerState
        }
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
    
    $result.Success = $false
    $result.Message = "Error: $($_.Exception.Message)"
    
    throw
}
finally {
    # Calculate duration
    $endTime = Get-Date
    $duration = $endTime - $startTime
    $result.Duration = "$($duration.Minutes)m $($duration.Seconds)s"
    
    # Output summary
    Write-Output ""
    Write-Output "========================================="
    Write-Output "SUMMARY"
    Write-Output "========================================="
    Write-Output "Resource Group: $($result.ResourceGroup)"
    Write-Output "VM Name: $($result.VMName)"
    Write-Output "Initial State: $($result.InitialPowerState)"
    Write-Output "Final State: $($result.FinalPowerState)"
    Write-Output "Action Taken: $($result.ActionTaken)"
    Write-Output "Success: $($result.Success)"
    Write-Output "Message: $($result.Message)"
    Write-Output "Duration: $($result.Duration)"
    Write-Output "========================================="
    
    # Output as JSON for programmatic consumption
    Write-Output ""
    Write-Output "JSON Output:"
    Write-Output ($result | ConvertTo-Json -Compress)
}
