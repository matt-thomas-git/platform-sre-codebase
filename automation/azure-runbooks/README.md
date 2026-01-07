# Azure Automation Runbooks

Production Azure Automation runbooks for automated infrastructure management and monitoring.

## Overview

This directory contains PowerShell runbooks designed to run in Azure Automation accounts. These runbooks leverage Azure Managed Identity for authentication and are scheduled to run automatically.

## Runbooks

### Check-And-Start-VM.ps1
**Purpose:** Automatically starts deallocated Azure VMs based on tags or schedules

**Features:**
- Checks VM power state
- Starts VMs that should be running
- Tag-based filtering
- Scheduled execution support

**Schedule:** Runs every 15 minutes (configurable)

**Authentication:** Azure Managed Identity

**Example Usage:**
```powershell
# Runs automatically in Azure Automation
# Checks all VMs with tag "AutoStart:True"
```

---

### Monitor-Backup-Health.ps1
**Purpose:** Monitors Azure Backup job status and alerts on failures

**Features:**
- Queries Recovery Services Vaults
- Checks backup job status
- Identifies failed or missed backups
- Sends alerts for failures

**Schedule:** Runs hourly

**Authentication:** Azure Managed Identity

**Required Permissions:**
- Recovery Services Vault Reader
- Backup Reader

**Example Usage:**
```powershell
# Runs automatically in Azure Automation
# Checks all Recovery Services Vaults in subscription
```

---

## Azure Automation Setup

### Prerequisites

1. **Azure Automation Account** with System-Assigned Managed Identity enabled
2. **RBAC Permissions** assigned to the Managed Identity:
   - Virtual Machine Contributor (for VM operations)
   - Backup Reader (for backup monitoring)
   - Recovery Services Vault Reader

### Deployment Steps

1. **Create Azure Automation Account:**
   ```powershell
   New-AzAutomationAccount -ResourceGroupName "automation-rg" `
       -Name "platform-automation" `
       -Location "East US 2" `
       -AssignSystemIdentity
   ```

2. **Assign Permissions:**
   ```powershell
   $automationAccount = Get-AzAutomationAccount -ResourceGroupName "automation-rg" -Name "platform-automation"
   
   New-AzRoleAssignment -ObjectId $automationAccount.Identity.PrincipalId `
       -RoleDefinitionName "Virtual Machine Contributor" `
       -Scope "/subscriptions/{subscription-id}"
   ```

3. **Import Runbook:**
   ```powershell
   Import-AzAutomationRunbook -ResourceGroupName "automation-rg" `
       -AutomationAccountName "platform-automation" `
       -Path ".\Check-And-Start-VM.ps1" `
       -Type PowerShell `
       -Name "Check-And-Start-VM"
   ```

4. **Publish Runbook:**
   ```powershell
   Publish-AzAutomationRunbook -ResourceGroupName "automation-rg" `
       -AutomationAccountName "platform-automation" `
       -Name "Check-And-Start-VM"
   ```

5. **Create Schedule:**
   ```powershell
   New-AzAutomationSchedule -ResourceGroupName "automation-rg" `
       -AutomationAccountName "platform-automation" `
       -Name "Every15Minutes" `
       -StartTime (Get-Date).AddMinutes(15) `
       -FrequencyInterval 15 `
       -FrequencyType Minute
   
   Register-AzAutomationScheduledRunbook -ResourceGroupName "automation-rg" `
       -AutomationAccountName "platform-automation" `
       -RunbookName "Check-And-Start-VM" `
       -ScheduleName "Every15Minutes"
   ```

---

## Authentication Pattern

All runbooks use **Azure Managed Identity** for authentication:

```powershell
# Connect using Managed Identity (no credentials needed)
Connect-AzAccount -Identity

# Query resources using the Managed Identity's permissions
Get-AzVM -ResourceGroupName "production-rg"
```

**Benefits:**
- ✅ No secrets to manage
- ✅ Automatic credential rotation
- ✅ Tightly scoped permissions via RBAC
- ✅ Audit trail of all actions

---

## Monitoring & Logging

### View Runbook Execution History

```powershell
Get-AzAutomationJob -ResourceGroupName "automation-rg" `
    -AutomationAccountName "platform-automation" `
    -RunbookName "Check-And-Start-VM" `
    | Select-Object JobId, Status, StartTime, EndTime
```

### View Runbook Output

```powershell
$job = Get-AzAutomationJob -ResourceGroupName "automation-rg" `
    -AutomationAccountName "platform-automation" `
    -RunbookName "Check-And-Start-VM" `
    | Sort-Object StartTime -Descending | Select-Object -First 1

Get-AzAutomationJobOutput -ResourceGroupName "automation-rg" `
    -AutomationAccountName "platform-automation" `
    -JobId $job.JobId `
    -Stream Output
```

---

## Best Practices

1. **Idempotency:** All runbooks are designed to be safely re-run
2. **Error Handling:** Comprehensive try/catch blocks with detailed logging
3. **Least Privilege:** Managed Identity has only required permissions
4. **Logging:** All actions logged with timestamps and severity levels
5. **Testing:** Test in non-production before deploying to production

---

## Troubleshooting

### "Managed Identity not found"
**Solution:** Enable System-Assigned Managed Identity on the Automation Account

### "Insufficient permissions"
**Solution:** Verify RBAC role assignments for the Managed Identity

### "Runbook failed to start"
**Solution:** Check runbook is published and schedule is active

---

## Related Documentation

- [Azure Automation Documentation](https://docs.microsoft.com/en-us/azure/automation/)
- [Managed Identities](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)
- [Authentication Modes](../../docs/AUTH-MODES.md)

---

**Note:** These runbooks are production-tested and sanitized for portfolio use. All company-specific information has been removed.
