# Idempotency & Safe Reruns

This document explains how scripts in this portfolio handle reruns, duplicate operations, and state management to ensure safe, repeatable automation.

---

## 🔄 What is Idempotency?

**Idempotency** means that running an operation multiple times produces the same result as running it once. This is critical for:

- **CI/CD Pipelines** - Pipelines may retry on transient failures
- **Scheduled Jobs** - Automation runs repeatedly on a schedule
- **Manual Reruns** - Operators may need to rerun scripts after failures
- **Disaster Recovery** - Rebuilding infrastructure from code

**Key Principle:** Scripts should check current state before making changes, not blindly apply operations.

---

## ✅ Idempotency Patterns Used in This Portfolio

### 1. Check-Before-Change Pattern

**Pattern:** Query current state, only make changes if needed

**Example - Azure VM Tagging:**
```powershell
# Get current VM tags
$vm = Get-AzVM -ResourceGroupName $rgName -Name $vmName
$currentTags = $vm.Tags

# Only update if tags are different
$newTags = @{Environment="Production"; Owner="Platform"}

$tagsToAdd = @{}
foreach ($key in $newTags.Keys) {
    if (-not $currentTags.ContainsKey($key) -or $currentTags[$key] -ne $newTags[$key]) {
        $tagsToAdd[$key] = $newTags[$key]
    }
}

if ($tagsToAdd.Count -gt 0) {
    Update-AzTag -ResourceId $vm.Id -Tag $tagsToAdd -Operation Merge
    Write-Host "Updated $($tagsToAdd.Count) tags"
} else {
    Write-Host "No tag changes needed - already up to date"
}
```

**Benefits:**
- ✅ Safe to rerun
- ✅ No unnecessary API calls
- ✅ Clear logging of what changed

---

### 2. Merge vs Replace Pattern

**Pattern:** Merge new values with existing values instead of replacing

**Example - Azure SQL Firewall Rules:**
```powershell
# Get existing firewall rules
$existingRules = Get-AzSqlServerFirewallRule -ResourceGroupName $rgName -ServerName $serverName

# Add new rules only if they don't exist
foreach ($newRule in $configRules) {
    $existing = $existingRules | Where-Object { $_.FirewallRuleName -eq $newRule.Name }
    
    if ($existing) {
        # Check if IP range changed
        if ($existing.StartIpAddress -ne $newRule.StartIP -or $existing.EndIpAddress -ne $newRule.EndIP) {
            # Update existing rule
            Set-AzSqlServerFirewallRule -ResourceGroupName $rgName -ServerName $serverName `
                -FirewallRuleName $newRule.Name `
                -StartIpAddress $newRule.StartIP -EndIpAddress $newRule.EndIP
            Write-Host "Updated firewall rule: $($newRule.Name)"
        } else {
            Write-Host "Firewall rule unchanged: $($newRule.Name)"
        }
    } else {
        # Create new rule
        New-AzSqlServerFirewallRule -ResourceGroupName $rgName -ServerName $serverName `
            -FirewallRuleName $newRule.Name `
            -StartIpAddress $newRule.StartIP -EndIpAddress $newRule.EndIP
        Write-Host "Created firewall rule: $($newRule.Name)"
    }
}
```

**Benefits:**
- ✅ Preserves existing configuration
- ✅ Only changes what's necessary
- ✅ Detailed change tracking

---

### 3. SQL Role Membership Idempotency

**Pattern:** Check membership before adding users to roles

**Example - SQL Server Permissions:**
```sql
-- Check if user exists in database
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'DOMAIN\AppUser')
BEGIN
    CREATE USER [DOMAIN\AppUser] FROM LOGIN [DOMAIN\AppUser]
    PRINT 'Created user: DOMAIN\AppUser'
END
ELSE
BEGIN
    PRINT 'User already exists: DOMAIN\AppUser'
END

-- Check if user is already in role
IF NOT IS_ROLEMEMBER('db_datareader', 'DOMAIN\AppUser') = 1
BEGIN
    ALTER ROLE db_datareader ADD MEMBER [DOMAIN\AppUser]
    PRINT 'Added DOMAIN\AppUser to db_datareader'
END
ELSE
BEGIN
    PRINT 'DOMAIN\AppUser already in db_datareader'
END
```

**PowerShell Implementation:**
```powershell
# Check current role membership
$checkQuery = @"
SELECT IS_ROLEMEMBER('$roleName', '$userName') as IsMember
"@

$result = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $checkQuery

if ($result.IsMember -eq 1) {
    Write-Host "User $userName already in role $roleName - skipping"
} else {
    $addQuery = "ALTER ROLE [$roleName] ADD MEMBER [$userName]"
    Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $addQuery
    Write-Host "Added $userName to $roleName"
}
```

**Benefits:**
- ✅ No errors on duplicate role assignments
- ✅ Safe for pipeline retries
- ✅ Clear audit trail

---

### 4. Terraform State Management

**Pattern:** Terraform automatically handles idempotency through state files

**Example - Azure VM Deployment:**
```hcl
resource "azurerm_windows_virtual_machine" "sql_server" {
  name                = "sql-prod-01"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_D4s_v3"
  
  # Terraform tracks this resource in state
  # Running 'terraform apply' again will:
  # - Do nothing if no changes
  # - Update only changed attributes
  # - Never duplicate the VM
}
```

**Terraform Idempotency:**
```bash
# First run - creates resources
terraform apply

# Second run - no changes
terraform apply
# Output: "No changes. Your infrastructure matches the configuration."

# After config change - updates only what changed
terraform apply
# Output: "Plan: 0 to add, 1 to change, 0 to destroy"
```

**Benefits:**
- ✅ Built-in state tracking
- ✅ Automatic change detection
- ✅ Safe to run repeatedly

---

## 🛡️ Handling Common Rerun Scenarios

### Scenario 1: Pipeline Retry After Transient Failure

**Problem:** Network timeout during Azure API call, pipeline retries

**Solution:** Use retry logic with idempotent operations

```powershell
function Invoke-Retry {
    param(
        [ScriptBlock]$ScriptBlock,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 5
    )
    
    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            return & $ScriptBlock
        } catch {
            if ($attempt -eq $MaxRetries) {
                throw
            }
            Write-Warning "Attempt $attempt failed: $($_.Exception.Message). Retrying in $DelaySeconds seconds..."
            Start-Sleep -Seconds $DelaySeconds
            $attempt++
        }
    }
}

# Usage - safe to retry because we check before changing
Invoke-Retry {
    $vm = Get-AzVM -ResourceGroupName $rgName -Name $vmName
    if ($vm.Tags['Environment'] -ne 'Production') {
        Update-AzTag -ResourceId $vm.Id -Tag @{Environment='Production'} -Operation Merge
    }
}
```

---

### Scenario 2: Duplicate Role Membership

**Problem:** User already in SQL role, script tries to add again

**Bad Approach (Not Idempotent):**
```sql
-- This will fail on second run
ALTER ROLE db_datareader ADD MEMBER [DOMAIN\AppUser]
-- Error: User or role 'DOMAIN\AppUser' already exists in the current database
```

**Good Approach (Idempotent):**
```sql
-- Check first, then add
IF NOT IS_ROLEMEMBER('db_datareader', 'DOMAIN\AppUser') = 1
BEGIN
    ALTER ROLE db_datareader ADD MEMBER [DOMAIN\AppUser]
    PRINT 'Added user to role'
END
ELSE
BEGIN
    PRINT 'User already in role - no action needed'
END
```

---

### Scenario 3: Configuration Drift Detection

**Problem:** Manual changes made outside automation, need to detect and correct

**Solution:** Compare desired state vs actual state

```powershell
# Desired state from config file
$desiredTags = @{
    Environment = "Production"
    CostCenter  = "IT-OPS"
    Owner       = "Platform Team"
}

# Actual state from Azure
$vm = Get-AzVM -ResourceGroupName $rgName -Name $vmName
$actualTags = $vm.Tags

# Detect drift
$driftDetected = $false
$driftReport = @()

foreach ($key in $desiredTags.Keys) {
    if (-not $actualTags.ContainsKey($key)) {
        $driftReport += "Missing tag: $key"
        $driftDetected = $true
    } elseif ($actualTags[$key] -ne $desiredTags[$key]) {
        $driftReport += "Tag mismatch: $key (Expected: $($desiredTags[$key]), Actual: $($actualTags[$key]))"
        $driftDetected = $true
    }
}

if ($driftDetected) {
    Write-Warning "Configuration drift detected:"
    $driftReport | ForEach-Object { Write-Warning "  $_" }
    
    # Remediate drift
    Update-AzTag -ResourceId $vm.Id -Tag $desiredTags -Operation Merge
    Write-Host "Drift corrected"
} else {
    Write-Host "No drift detected - configuration matches desired state"
}
```

---

## 📊 Idempotency Testing

### Test 1: Run Twice, Same Result

```powershell
# First run
.\Set-AzureVmTagsFromPolicy.ps1 -SubscriptionId "abc-123" -Mode Apply
# Output: "Updated 5 VMs with 3 tags each"

# Second run (immediate)
.\Set-AzureVmTagsFromPolicy.ps1 -SubscriptionId "abc-123" -Mode Apply
# Output: "0 VMs updated - all tags already correct"
```

**Expected:** Second run makes no changes

---

### Test 2: Partial Failure Recovery

```powershell
# Run 1: Processes 10 servers, fails on server 7
.\Get-ServerAdminAudit.ps1 -ComputerListPath "servers.txt"
# Output: "Success: 6, Failed: 4"

# Run 2: Rerun after fixing network issue
.\Get-ServerAdminAudit.ps1 -ComputerListPath "servers.txt"
# Output: "Success: 10, Failed: 0"
# Note: Servers 1-6 are re-audited but produce same results
```

**Expected:** Script safely re-processes successful servers

---

### Test 3: SQL Role Assignment Rerun

```powershell
# Run 1: Add users to roles
.\SQL-Permissions-Orchestrator.ps1 -ConfigPath "config.json" -Environment "PROD"
# Output: "Added 15 users to roles"

# Run 2: Rerun same config
.\SQL-Permissions-Orchestrator.ps1 -ConfigPath "config.json" -Environment "PROD"
# Output: "0 changes - all users already have correct permissions"
```

**Expected:** No errors, no duplicate role memberships

---

## ⚠️ Non-Idempotent Operations (Handle with Care)

Some operations are inherently non-idempotent and require special handling:

### 1. Appending to Files/Logs
```powershell
# Bad - appends every time
Add-Content -Path "log.txt" -Value "Script ran at $(Get-Date)"

# Good - check if entry exists
$logEntry = "Script ran at $(Get-Date -Format 'yyyy-MM-dd')"
$existingLog = Get-Content "log.txt" -ErrorAction SilentlyContinue
if ($existingLog -notcontains $logEntry) {
    Add-Content -Path "log.txt" -Value $logEntry
}
```

### 2. Incrementing Counters
```powershell
# Bad - increments every time
$counter = Get-Content "counter.txt"
$counter++
Set-Content "counter.txt" -Value $counter

# Good - set to specific value based on state
$expectedCount = (Get-ChildItem "processed\").Count
Set-Content "counter.txt" -Value $expectedCount
```

### 3. Sending Notifications
```powershell
# Bad - sends email every run
Send-MailMessage -To "admin@company.com" -Subject "Backup Complete"

# Good - only send if state changed
if ($backupStatus -ne $previousBackupStatus) {
    Send-MailMessage -To "admin@company.com" -Subject "Backup Status Changed: $backupStatus"
}
```

---

## 🎯 Best Practices Summary

### ✅ DO:
1. **Check current state before making changes**
2. **Use merge operations instead of replace**
3. **Log what changed vs what was skipped**
4. **Handle "already exists" errors gracefully**
5. **Use `-WhatIf` to preview changes**
6. **Test scripts by running them twice**
7. **Use Terraform for infrastructure (built-in idempotency)**

### ❌ DON'T:
1. **Assume resources don't exist**
2. **Blindly apply changes without checking**
3. **Fail on "already exists" errors**
4. **Append to files without checking**
5. **Send duplicate notifications**
6. **Increment counters without state checks**

---

## 📚 Related Documentation

- [PowerShell ShouldProcess](https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-shouldprocess)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)
- [Azure Resource Manager Idempotency](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/overview)

---

## 🔍 Troubleshooting

### "User already exists" errors
**Cause:** Script not checking before creating
**Solution:** Add `IF NOT EXISTS` checks in SQL or PowerShell

### Duplicate tags/resources
**Cause:** Using replace instead of merge
**Solution:** Use `-Operation Merge` for Azure tags

### Pipeline fails on retry
**Cause:** Non-idempotent operations
**Solution:** Implement check-before-change pattern

---

**Last Updated:** January 2026  
**Maintained By:** Platform SRE Team
