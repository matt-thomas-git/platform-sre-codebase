# Contributing to Platform SRE Automation Portfolio

Thank you for your interest in this portfolio! This document provides guidance on how to safely fork, test, and use these automation scripts in your own environment.

---

## 🍴 Safe to Fork

This repository is **safe to fork and use** as a reference or starting point for your own automation projects. All company-specific information has been sanitized and replaced with generic examples.

### What's Been Sanitized:
- ✅ Company names, product names, customer names
- ✅ Tenant IDs, subscription IDs, resource IDs
- ✅ Server hostnames, domain names, IP addresses
- ✅ Email addresses, usernames, service accounts
- ✅ Internal URLs, ticket numbers, change requests
- ✅ All secrets, credentials, and sensitive data

### Before Using in Your Environment:

1. **Update Configuration Files**
   - Replace placeholder values with your actual Azure/environment details
   - Update `*.example` files and rename to remove `.example` suffix
   - Never commit real credentials or secrets to Git

2. **Review Permissions**
   - Verify RBAC roles match your security requirements
   - Adjust least-privilege scopes as needed
   - Test with read-only permissions first

3. **Test in Non-Production**
   - Always test in Dev/UAT environments first
   - Use `-WhatIf` or `-DryRun` modes extensively
   - Validate outputs before applying to production

---

## 🧪 Testing Scripts Safely

### 1. Always Use -WhatIf Mode First

All PowerShell scripts that make changes support `-WhatIf` to preview actions without executing them:

```powershell
# Preview what would be changed
.\Set-AzureVmTagsFromPolicy.ps1 -SubscriptionId "your-sub-id" -WhatIf

# Preview log cleanup
.\Invoke-LogCleanup.ps1 -WhatIf

# Preview SQL firewall changes
.\Set-AzureSqlFirewallRules.ps1 -ConfigPath "config.json" -WhatIf
```

**Expected Output:**
```
What if: Performing the operation "Update tags" on target "VM: web-prod-01".
What if: Would add tag: Environment=Production
What if: Would add tag: CostCenter=IT-OPS
```

### 2. Use List/Report Modes

Many scripts have a "list-only" mode that generates reports without making changes:

```powershell
# Azure VM Tagging - List mode
.\Set-AzureVmTagsFromPolicy.ps1 -Mode List

# Server Admin Audit - Read-only
.\Get-ServerAdminAudit.ps1 -ComputerName "SERVER01"

# SQL Health Check - Read-only
.\Get-SqlHealth.ps1 -ServerInstance "SQLSERVER01"
```

### 3. Test with Limited Scope

Start with a single resource, then expand:

```powershell
# Test on one VM first
.\Set-AzureVmTagsFromPolicy.ps1 -ResourceGroupName "test-rg" -WhatIf

# Then expand to full subscription
.\Set-AzureVmTagsFromPolicy.ps1 -SubscriptionId "your-sub-id" -WhatIf
```

### 4. Dry-Run in CI/CD Pipelines

For pipeline testing, use dry-run parameters:

```yaml
# Azure DevOps Pipeline - Test stage
- stage: Test
  jobs:
  - job: DryRun
    steps:
    - task: AzurePowerShell@5
      inputs:
        ScriptPath: 'automation/script.ps1'
        ScriptArguments: '-WhatIf -Verbose'
```

---

## 📝 Configuration File Guidelines

### Using .example Files

Configuration files are provided with `.example` suffix to prevent accidental commits of real data:

```bash
# 1. Copy example file
cp config/azure-sql-firewall-config.json.example config/azure-sql-firewall-config.json

# 2. Edit with your values
# 3. Add to .gitignore (already configured)
# 4. Never commit the real config file
```

### Example Configuration Structure:

```json
{
  "subscriptionId": "your-subscription-id-here",
  "resourceGroupName": "your-resource-group",
  "sqlServerName": "your-sql-server",
  "firewallRules": [
    {
      "name": "AllowOfficeIP",
      "startIpAddress": "203.0.113.0",
      "endIpAddress": "203.0.113.255"
    }
  ]
}
```

### Configuration Validation

Scripts validate configuration before execution:

```powershell
# Script validates required fields
if (-not $config.subscriptionId -or $config.subscriptionId -eq "your-subscription-id-here") {
    throw "Please update subscriptionId in config file"
}
```

---

## 🔐 Security Best Practices

### Never Commit Secrets

```bash
# ❌ DON'T commit these files:
config/production-config.json
secrets.txt
.env
*.pfx
*.key

# ✅ These are already in .gitignore
```

### Use Azure Key Vault for Secrets

```powershell
# Store secrets in Key Vault
$secret = Get-AzKeyVaultSecret -VaultName "your-kv" -Name "sql-password" -AsPlainText

# Use in scripts
$securePassword = ConvertTo-SecureString $secret -AsPlainText -Force
$credential = New-Object PSCredential("sqladmin", $securePassword)
```

### Clear Sensitive Variables

```powershell
# After use, clear from memory
$password = $null
$credential = $null
[System.GC]::Collect()
```

---

## 🚀 Running Scripts Locally

### Prerequisites

1. **PowerShell 5.1 or later** (PowerShell 7+ recommended)
   ```powershell
   $PSVersionTable.PSVersion
   ```

2. **Required Modules** (scripts auto-install if missing)
   - Az PowerShell Module
   - SqlServer Module
   - ActiveDirectory Module (for AD scripts)

3. **Appropriate Permissions**
   - Azure: Reader minimum for list operations
   - Azure: Contributor for modification operations
   - SQL: VIEW SERVER STATE for health checks
   - Windows: Local Admin for server management scripts

### Example: Running Azure VM Tagging Script

```powershell
# 1. Connect to Azure
Connect-AzAccount

# 2. Select subscription
Set-AzContext -SubscriptionId "your-subscription-id"

# 3. Preview changes
.\Set-AzureVmTagsFromPolicy.ps1 -Mode List

# 4. Review output, then apply if satisfied
.\Set-AzureVmTagsFromPolicy.ps1 -Mode Apply -WhatIf

# 5. Execute (only after validating WhatIf output)
.\Set-AzureVmTagsFromPolicy.ps1 -Mode Apply
```

---

## 🔄 Idempotency & Reruns

All scripts are designed to be **idempotent** - safe to run multiple times:

```powershell
# First run - makes changes
.\Set-AzureVmTagsFromPolicy.ps1 -Mode Apply
# Output: "Updated 10 VMs with 3 tags each"

# Second run - no changes needed
.\Set-AzureVmTagsFromPolicy.ps1 -Mode Apply
# Output: "0 VMs updated - all tags already correct"
```

**Benefits:**
- ✅ Safe for CI/CD pipeline retries
- ✅ No errors on duplicate operations
- ✅ Clear logging of what changed vs. skipped

See [docs/IDEMPOTENCY-RERUNS.md](docs/IDEMPOTENCY-RERUNS.md) for detailed patterns.

---

## 📊 Understanding Script Output

### Verbose Logging

Enable verbose output for troubleshooting:

```powershell
.\script.ps1 -Verbose
```

### Structured Logging

Scripts use consistent logging levels:

```
[INFO] Starting Azure VM tagging process
[INFO] Found 15 VMs in subscription
[WARNING] VM 'test-vm-01' has no tags - will apply defaults
[SUCCESS] Updated tags on VM 'prod-web-01'
[ERROR] Failed to update VM 'broken-vm-02': Access denied
[INFO] Process complete: 14 success, 1 failed
```

### CSV Exports

Most scripts export results to CSV for analysis:

```powershell
# Default export location
C:\temp\ScriptName_YYYYMMDD_HHMMSS.csv

# Custom export path
.\script.ps1 -ExportPath "C:\Reports\output.csv"
```

---

## 🐛 Troubleshooting

### Common Issues

#### "Connect-AzAccount: No subscription found"
**Solution:** Verify you have permissions on the subscription
```powershell
Get-AzSubscription
Set-AzContext -SubscriptionId "your-sub-id"
```

#### "Module not found"
**Solution:** Install required module
```powershell
Install-Module -Name Az -Force -AllowClobber
Install-Module -Name SqlServer -Force
```

#### "Access Denied"
**Solution:** Verify RBAC permissions
```powershell
# Check your role assignments
Get-AzRoleAssignment -SignInName "your-email@company.com"
```

#### "WhatIf not working"
**Solution:** Ensure script supports ShouldProcess
```powershell
# Check script has [CmdletBinding(SupportsShouldProcess)]
Get-Help .\script.ps1 -Full
```

---

## 📚 Additional Resources

### Documentation
- [Authentication Modes](docs/AUTH-MODES.md) - Local, CI/CD, Managed Identity, OIDC
- [Idempotency Patterns](docs/IDEMPOTENCY-RERUNS.md) - Safe reruns and state management
- [Security Notes](docs/SECURITY-NOTES.md) - Secrets, sanitization, least privilege

### Script-Specific Guides
- [Automation Scripts Usage Guide](automation/powershell/scripts/examples/USAGE-GUIDE.md)
- [Terraform Deployment Guide](terraform/README.md)
- [Windows Updates Pipeline](cicd-pipelines/windows-updates-pipeline/README.md)
- [Dynatrace Automation](observability/dynatrace/README.md)

---

## 🤝 Feedback & Questions

This is a portfolio repository showcasing production automation work. While it's not actively maintained for external contributions, feedback is welcome:

- **Found an issue?** Open a GitHub issue
- **Have a question?** Check the documentation first, then open a discussion
- **Want to adapt for your use?** Fork away! Just remember to update configs and test thoroughly

---

## ⚖️ License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

This portfolio represents 2+ years of Platform/SRE work across:
- Azure cloud infrastructure
- Windows Server management
- SQL Server operations
- CI/CD pipeline development
- Observability and monitoring
- Security and compliance automation

All code has been sanitized and is safe for public sharing while maintaining technical integrity.

---

**Remember:** Always test in non-production first, use `-WhatIf` extensively, and never commit secrets to Git!

**Happy Automating! 🚀**
