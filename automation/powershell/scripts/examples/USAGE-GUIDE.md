# PowerShell Scripts Usage Guide

Quick reference for running the example automation scripts in this folder.

## Prerequisites

All scripts require:
- PowerShell 5.1 or later
- Appropriate permissions for the target systems
- Required PowerShell modules (scripts will attempt to install if missing)

## Scripts Overview

### 1. Invoke-LogCleanup.ps1

**Purpose:** Automated log file cleanup with retention policies across multiple servers

**Basic Usage:**
```powershell
# Run locally with default settings
.\Invoke-LogCleanup.ps1

# Run on specific remote servers
.\Invoke-LogCleanup.ps1 -ComputerName "SERVER01","SERVER02","SERVER03"

# Run on servers from file
.\Invoke-LogCleanup.ps1 -ComputerListPath "C:\servers.txt"

# Run using hardcoded server array (edit script first - see Configuration Mode below)
# 1. Edit the script file
# 2. Set $UseServersArray = 1
# 3. Fill in $ServersArray with your servers
# 4. Run: .\Invoke-LogCleanup.ps1
```

**Parameters:**
- `-ComputerName` - Array of remote server names (optional, runs locally if not specified)
- `-ComputerListPath` - Path to text file with server names (one per line)
- `-Credential` - PSCredential for remote authentication
- `-SQLRetentionDays` - Days to keep SQL logs (default: 0 = current only)
- `-IISRetentionDays` - Days to keep IIS logs (default: 30)
- `-SSHRetentionDays` - Days to keep SSH logs (default: 90)
- `-AutoConfirm` - Skip confirmation prompts

**Configuration Mode (Hardcoded Server Array):**

For portable/repeatable execution, edit the script's configuration section:

```powershell
#region Configuration - Edit This Section
# Set to 1 to use the hardcoded server array below, 0 to use parameters
$UseServersArray = 1  # Change from 0 to 1

# Hardcoded server list (only used if $UseServersArray = 1)
$ServersArray = @(
    "PROD-SQL-01",
    "PROD-SQL-02",
    "PROD-WEB-01"
)
#endregion
```

Then simply run: `.\Invoke-LogCleanup.ps1`

**Execution Modes:**
1. **Local Execution** - No ComputerName specified, runs on local machine
2. **Parameter-Based** - Specify servers via `-ComputerName` parameter
3. **File-Based** - Load servers from text file via `-ComputerListPath`
4. **Configuration-Based** - Edit script to set `$UseServersArray = 1` and define `$ServersArray`

**Examples:**
```powershell
# Local: Run with default settings
.\Invoke-LogCleanup.ps1

# Remote: Clean logs on multiple servers with custom retention
.\Invoke-LogCleanup.ps1 -ComputerName "SQL-01","SQL-02" -SQLRetentionDays 0 -IISRetentionDays 60

# Remote: Use server list file with credentials
$cred = Get-Credential
.\Invoke-LogCleanup.ps1 -ComputerListPath "C:\prod-servers.txt" -Credential $cred

# Configuration-based: Edit script first, then run
# (After setting $UseServersArray = 1 and filling $ServersArray in the script)
.\Invoke-LogCleanup.ps1 -IISRetentionDays 90 -AutoConfirm
```

**Output:**
- Console output with color-coded results per server
- CSV report: `C:\temp\LogCleanup_Report_<timestamp>.csv`
- Shows space freed per server and log type

---

### 2. Set-AzureVmTagsFromPolicy.ps1

**Purpose:** Manage Azure VM tags based on naming conventions

**Basic Usage:**
```powershell
# Interactive mode - prompts for actions
.\Set-AzureVmTagsFromPolicy.ps1

# Preview mode - see what tags would be applied
.\Set-AzureVmTagsFromPolicy.ps1 -WhatIf

# Target specific subscription
.\Set-AzureVmTagsFromPolicy.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"
```

**Parameters:**
- `-TenantId` - Azure Tenant ID (optional, uses default if not specified)
- `-SubscriptionId` - Specific subscription to process (optional, processes all if not specified)
- `-ExportPath` - Custom path for CSV export (optional)
- `-WhatIf` - Preview mode without making changes

**Interactive Menu:**
1. List all VMs with their tags
2. Add tags to VMs based on naming patterns
3. Both - List VMs and then add tags

**Naming Patterns:**
- `PROD-*` → Environment=Production
- `UAT-*` → Environment=UAT
- `DEV-*` → Environment=Development
- `*-WEB-*` → Role=WebServer
- `*-APP-*` → Role=ApplicationServer
- `*-SQL-*` → Role=DatabaseServer

**Examples:**
```powershell
# Preview what tags would be applied
.\Set-AzureVmTagsFromPolicy.ps1 -WhatIf
# Then select option 2 from menu

# Actually apply tags to specific subscription
.\Set-AzureVmTagsFromPolicy.ps1 -SubscriptionId "abc-123-def"
# Then select option 2 and confirm

# List all VMs and export to custom location
.\Set-AzureVmTagsFromPolicy.ps1 -ExportPath "D:\Reports\VM_Tags.csv"
# Then select option 1
```

**Output:**
- Console output with VM details and tag changes
- CSV report with results

---

### 3. Set-AzureSqlFirewallRules.ps1

**Purpose:** Azure SQL Database firewall rule management

**Basic Usage:**
```powershell
# Export current firewall rules (audit mode)
.\Set-AzureSqlFirewallRules.ps1 -SubscriptionId "abc-123" -ResourceGroupName "sql-rg" -ExportOnly

# Interactive mode - prompts for servers and IPs
.\Set-AzureSqlFirewallRules.ps1 -SubscriptionId "abc-123" -ResourceGroupName "sql-rg"

# Use configuration file
.\Set-AzureSqlFirewallRules.ps1 -ConfigPath ".\config\azure-sql-firewall-config.json"

# Preview mode with WhatIf
.\Set-AzureSqlFirewallRules.ps1 -ConfigPath ".\config\azure-sql-firewall-config.json" -WhatIf
```

**Parameters:**
- `-SubscriptionId` - Azure Subscription ID
- `-ResourceGroupName` - Resource Group containing SQL servers
- `-ConfigPath` - Path to JSON configuration file
- `-ExportOnly` - Export current rules without making changes
- `-ExportPath` - Custom path for CSV export
- `-WhatIf` - Preview mode without making changes

**Configuration File Format:**
```json
{
  "resourceGroup": "sql-resource-group",
  "servers": {
    "sqlserver1.database.windows.net": [],
    "sqlserver2.database.windows.net": []
  },
  "ipRulesToAdd": [
    { "name": "Office-IP-1", "ip": "203.0.113.10" },
    { "name": "Office-IP-2", "ip": "203.0.113.11" }
  ],
  "ipRulesToRemove": ["198.51.100.5", "198.51.100.6"]
}
```

**Examples:**
```powershell
# Audit current firewall rules
.\Set-AzureSqlFirewallRules.ps1 -SubscriptionId "abc-123" -ResourceGroupName "sql-rg" -ExportOnly

# Preview changes from config file
.\Set-AzureSqlFirewallRules.ps1 -ConfigPath ".\config\azure-sql-firewall-config.json" -WhatIf

# Apply firewall rule changes
.\Set-AzureSqlFirewallRules.ps1 -ConfigPath ".\config\azure-sql-firewall-config.json"
```

**Output:**
- Console output with rule changes
- CSV export of current/final firewall rules

---

### 4. Get-ServerAdminAudit.ps1

**Purpose:** Audit local administrators and RDP users across Windows servers

**Basic Usage:**
```powershell
# Audit specific servers
.\Get-ServerAdminAudit.ps1 -ComputerName "SERVER01","SERVER02","SERVER03"

# Audit servers using hardcoded array
.\Get-ServerAdminAudit.ps1 -UseServersArray

# Audit servers from a list file
.\Get-ServerAdminAudit.ps1 -ComputerListPath "C:\servers.txt"

# Include built-in accounts in report
.\Get-ServerAdminAudit.ps1 -ComputerName "SERVER01" -IncludeBuiltIn

# Use alternate credentials
$cred = Get-Credential
.\Get-ServerAdminAudit.ps1 -ComputerName "SERVER01" -Credential $cred
```

**Parameters:**
- `-ComputerName` - Array of server names to audit
- `-ComputerListPath` - Path to text file with server names (one per line)
- `-UseServersArray` - Use hardcoded server array in script: 1 = use array, 0 = don't use (portable configuration)
- `-ExportPath` - Custom path for CSV export
- `-IncludeBuiltIn` - Include built-in accounts (Administrator, Domain Admins)
- `-Credential` - PSCredential for remote authentication

**Execution Modes:**
1. **Parameter Array** - Specify servers via `-ComputerName`
2. **File-Based** - Load servers from text file via `-ComputerListPath`
3. **Hardcoded Array** - Use `-UseServersArray` for portable server list

**Server List File Format (servers.txt):**
```
SERVER01
SERVER02
SERVER03
```

**Examples:**
```powershell
# Quick audit of production servers
.\Get-ServerAdminAudit.ps1 -ComputerName "PROD-WEB-01","PROD-APP-01","PROD-SQL-01"

# Use hardcoded server array (portable)
.\Get-ServerAdminAudit.ps1 -UseServersArray 1 -IncludeBuiltIn

# Audit all servers from list
.\Get-ServerAdminAudit.ps1 -ComputerListPath "\\share\server-lists\production-servers.txt"

# Compliance audit including all accounts
.\Get-ServerAdminAudit.ps1 -ComputerListPath "C:\servers.txt" -IncludeBuiltIn -ExportPath "D:\Audits\Admin_Audit.csv"

# Audit with domain admin credentials
$cred = Get-Credential "DOMAIN\AdminUser"
.\Get-ServerAdminAudit.ps1 -ComputerName "SERVER01" -Credential $cred
```

**Output:**
- Console output with detailed results per server
- CSV report:
  - `ServerAdminAudit_<timestamp>.csv`
- Shows:
  - Server name
  - Group type (Administrators / Remote Desktop Users)
  - Member name and type
  - Success/failure status

---

### 5. Get-SqlHealth.ps1

**Purpose:** SQL Server health check and reporting across multiple servers

**Basic Usage:**
```powershell
# Check local SQL Server instance
.\Get-SqlHealth.ps1

# Check specific remote SQL Server
.\Get-SqlHealth.ps1 -ServerName "SQL-SERVER-01"

# Check multiple SQL Servers
.\Get-SqlHealth.ps1 -ServerName "SQL-01","SQL-02","SQL-03"

# Use hardcoded server array
.\Get-SqlHealth.ps1 -UseServersArray

# Check servers from file
.\Get-SqlHealth.ps1 -ServerListPath "C:\sql-servers.txt"

# Check specific instance
.\Get-SqlHealth.ps1 -ServerName "SQL-SERVER-01\INSTANCE01"

# Export to custom location
.\Get-SqlHealth.ps1 -ServerName "SQL-SERVER-01" -ExportPath "D:\Reports"
```

**Parameters:**
- `-ServerName` - SQL Server instance name(s) - single server or array (default: localhost)
- `-ServerListPath` - Path to text file with server names (one per line)
- `-UseServersArray` - Use hardcoded server array in script: 1 = use array, 0 = don't use (portable configuration)
- `-ExportPath` - Directory for CSV export (default: C:\temp)

**Execution Modes:**
1. **Single Server** - Specify one server via `-ServerName`
2. **Multiple Servers** - Specify array via `-ServerName`
3. **File-Based** - Load servers from text file via `-ServerListPath`
4. **Hardcoded Array** - Use `-UseServersArray` for portable server list

**Health Checks Performed:**
- Database status and sizes
- Backup status (last full, differential, log backups)
- SQL Agent job status
- Disk space on SQL Server drives
- TempDB configuration
- Error log analysis

**Examples:**
```powershell
# Quick health check of local instance
.\Get-SqlHealth.ps1

# Check multiple production SQL Servers
.\Get-SqlHealth.ps1 -ServerName "PROD-SQL-01","PROD-SQL-02","PROD-SQL-03"

# Use hardcoded server array (portable)
.\Get-SqlHealth.ps1 -UseServersArray 1 -ExportPath "D:\Reports"

# Check all servers from list file
.\Get-SqlHealth.ps1 -ServerListPath "\\share\sql-servers.txt"

# Full health check of production SQL Server
.\Get-SqlHealth.ps1 -ServerName "PROD-SQL-01" -ExportPath "\\reports\sql-health"

# Check named instance
.\Get-SqlHealth.ps1 -ServerName "SQL-SERVER\SQLEXPRESS"
```

**Output:**
- Console output with health check results per server
- CSV reports (one per server):
  - `SqlHealth_<ServerName>_Databases_<timestamp>.csv`
  - `SqlHealth_<ServerName>_Backups_<timestamp>.csv`
  - `SqlHealth_<ServerName>_Jobs_<timestamp>.csv`
  - `SqlHealth_<ServerName>_DiskSpace_<timestamp>.csv`

---

## Common Patterns

### Running in WhatIf Mode

All scripts support preview mode to see what would happen without making changes:

```powershell
# Method 1: Use -WhatIf parameter
.\Set-AzureVmTagsFromPolicy.ps1 -WhatIf

# Method 2: Set WhatIf preference
$WhatIfPreference = $true
.\Invoke-LogCleanup.ps1
```

### Scheduling with Task Scheduler

Create a scheduled task to run scripts automatically:

```powershell
# Example: Schedule log cleanup to run weekly
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\Scripts\Invoke-LogCleanup.ps1 -RetentionDays 30 -WhatIf:`$false"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am

Register-ScheduledTask -TaskName "Weekly Log Cleanup" `
    -Action $action -Trigger $trigger -RunLevel Highest
```

### Running from Azure DevOps Pipeline

```yaml
- task: PowerShell@2
  inputs:
    filePath: 'automation/powershell/scripts/examples/Get-SqlHealth.ps1'
    arguments: '-ServerName $(SqlServerName) -ExportPath $(Build.ArtifactStagingDirectory)'
  displayName: 'SQL Server Health Check'
```

### Error Handling

All scripts include comprehensive error handling. Check the console output and CSV reports for details:

```powershell
# Run script and capture output
.\Get-SqlHealth.ps1 -ServerName "SQL-01" *>&1 | Tee-Object -FilePath "C:\logs\sql-health.log"
```

## Troubleshooting

### Module Not Found

If a script reports missing modules:

```powershell
# Install required modules manually
Install-Module -Name Az.Accounts -Force -AllowClobber
Install-Module -Name Az.Compute -Force -AllowClobber
Install-Module -Name SqlServer -Force -AllowClobber
```

### Permission Denied

Ensure you have:
- Local admin rights (for log cleanup)
- Azure Contributor role (for VM tagging)
- SQL Server sysadmin or appropriate permissions (for SQL health checks)

### Execution Policy

If scripts won't run due to execution policy:

```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or bypass for single execution
PowerShell.exe -ExecutionPolicy Bypass -File .\script.ps1
```

## Best Practices

1. **Always test in WhatIf mode first**
   ```powershell
   .\Invoke-LogCleanup.ps1 -WhatIf
   ```

2. **Review CSV reports before taking action**
   - Check the exported CSV files
   - Verify the scope of changes

3. **Use appropriate retention periods**
   - Development: 30 days
   - Production: 90+ days
   - Compliance requirements may dictate longer retention

4. **Schedule during maintenance windows**
   - Run cleanup scripts during low-usage periods
   - Avoid running during backups or maintenance

5. **Monitor script execution**
   - Review logs and reports
   - Set up alerts for failures
   - Track disk space savings

## Getting Help

Each script includes detailed help:

```powershell
# View full help
Get-Help .\Invoke-LogCleanup.ps1 -Full

# View examples only
Get-Help .\Set-AzureVmTagsFromPolicy.ps1 -Examples

# View parameter details
Get-Help .\Get-SqlHealth.ps1 -Parameter ServerName
```

## Support

For issues or questions:
1. Check the script's help documentation
2. Review the CSV output for error details
3. Check the main automation README
4. Review the module documentation in `../Module/`

## Version History

| Date | Script | Changes |
|------|--------|---------|
| 2024-01-15 | All | Initial portfolio versions |
| 2024-12-30 | Set-AzureVmTagsFromPolicy.ps1 | Fixed WhatIf parameter conflict |
