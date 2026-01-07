# PowerShell Automation Examples

This folder contains production-ready PowerShell scripts demonstrating real-world Platform SRE automation patterns. These scripts showcase best practices for infrastructure management, monitoring, and maintenance.

## Scripts Overview

### 1. Invoke-LogCleanup.ps1
**Multi-Service Log Cleanup Tool**

Automatically detects and cleans logs from SQL Server, IIS, and SSH Server installations.

**Features:**
- Auto-detection of service installations
- Configurable retention periods
- File size reporting (MB/GB)
- Safe deletion with confirmation prompts
- Progress tracking and space freed reporting

**Usage:**
```powershell
# Interactive mode with default retention
.\Invoke-LogCleanup.ps1

# Custom retention periods
.\Invoke-LogCleanup.ps1 -IISRetentionDays 60 -SSHRetentionDays 180

# Automated mode (no prompts)
.\Invoke-LogCleanup.ps1 -AutoConfirm
```

**Default Retention:**
- SQL Server: Current logs only
- IIS: 30 days
- SSH Server: 90 days

---

### 2. Set-AzureVmTagsFromPolicy.ps1
**Azure VM Tag Management**

Applies tags to Azure VMs based on naming conventions across multiple subscriptions.

**Features:**
- Multi-subscription support
- Pattern-based tag assignment
- Interactive or automated modes
- WhatIf support for preview
- CSV export of results

**Naming Patterns:**
- `PROD-*` → Environment=Production
- `UAT-*` → Environment=UAT
- `DEV-*` → Environment=Development
- `*-WEB-*` → Role=WebServer
- `*-APP-*` → Role=ApplicationServer
- `*-SQL-*` → Role=DatabaseServer
- `*-DC-*` → Role=DomainController

**Usage:**
```powershell
# Interactive mode
.\Set-AzureVmTagsFromPolicy.ps1

# Preview mode (no changes)
.\Set-AzureVmTagsFromPolicy.ps1 -WhatIf

# Specific subscription
.\Set-AzureVmTagsFromPolicy.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"

# Specific tenant
.\Set-AzureVmTagsFromPolicy.ps1 -TenantId "87654321-4321-4321-4321-210987654321"
```

**Requirements:**
- Az.Accounts module
- Az.Compute module
- Contributor or Tag Contributor role

---

### 3. Get-SqlHealth.ps1
**SQL Server Health Check**

Comprehensive health monitoring for SQL Server instances.

**Health Checks:**
- Server information and version
- Database status and sizes
- TempDB configuration
- Disk space monitoring
- Backup status (optional)
- SQL Agent job status (optional)
- Performance metrics (optional)

**Usage:**
```powershell
# Basic health check
.\Get-SqlHealth.ps1 -ServerInstance "SQLSERVER01"

# Comprehensive check with backups and jobs
.\Get-SqlHealth.ps1 -ServerInstance "SQLSERVER01" -CheckBackups -CheckJobs

# Include performance monitoring
.\Get-SqlHealth.ps1 -ServerInstance "SQLSERVER01" -CheckPerformance

# All checks with custom export path
.\Get-SqlHealth.ps1 -ServerInstance "SQLSERVER01" `
    -CheckBackups -CheckJobs -CheckPerformance `
    -ExportPath "C:\Reports\SQL_Health.csv"
```

**Performance Checks:**
- Blocking sessions detection
- Long-running queries (>5 minutes)
- Active connections

**Requirements:**
- SqlServer PowerShell module
- VIEW SERVER STATE permission
- VIEW ANY DATABASE permission

---

## Common Patterns Demonstrated

### 1. Parameter Validation
All scripts use proper parameter validation:
```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 365)]
    [int]$RetentionDays = 30
)
```

### 2. Error Handling
Robust try/catch blocks with meaningful error messages:
```powershell
try {
    # Operation
    Write-Host "Success" -ForegroundColor Green
} catch {
    Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
}
```

### 3. Progress Reporting
Color-coded output for easy status identification:
- **Green**: Success/OK
- **Yellow**: Warning/Preview
- **Red**: Error/Critical
- **Cyan**: Information
- **Gray**: Details

### 4. Export Capabilities
All scripts support CSV export for reporting:
```powershell
$results | Export-Csv -Path $ExportPath -NoTypeInformation
```

### 5. WhatIf Support
Preview mode to see changes before applying:
```powershell
[CmdletBinding(SupportsShouldProcess)]
param([switch]$WhatIf)

if ($WhatIf) {
    Write-Host "[PREVIEW] Would perform action" -ForegroundColor Yellow
} else {
    # Perform actual action
}
```

## Best Practices Implemented

### Safety Features
- **Confirmation prompts** for destructive operations
- **WhatIf/Preview modes** to validate changes
- **Detailed logging** of all operations
- **Error handling** with graceful degradation

### Performance
- **Efficient queries** for database operations
- **Batch processing** for multiple resources
- **Progress indicators** for long-running operations

### Maintainability
- **Comprehensive help** with examples
- **Modular functions** for reusability
- **Clear variable naming** and comments
- **Consistent formatting** and structure

### Security
- **No hardcoded credentials**
- **Secure authentication** (Azure AD, Windows Auth)
- **Minimal permissions** required
- **Audit trail** through logging

## Integration Examples

### Azure DevOps Pipeline
```yaml
- task: PowerShell@2
  inputs:
    filePath: 'automation/powershell/scripts/examples/Invoke-LogCleanup.ps1'
    arguments: '-AutoConfirm -IISRetentionDays 30'
  displayName: 'Clean Server Logs'
```

### Scheduled Task
```powershell
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
    -Argument '-File "C:\Scripts\Invoke-LogCleanup.ps1" -AutoConfirm'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am
Register-ScheduledTask -TaskName "Weekly Log Cleanup" -Action $action -Trigger $trigger
```

### With PlatformOps Module
```powershell
Import-Module .\automation\powershell\Module\PlatformOps.Automation.psd1

# Use retry logic for Azure operations
Invoke-Retry -ScriptBlock {
    .\Set-AzureVmTagsFromPolicy.ps1 -WhatIf
} -MaxRetries 3

# Log SQL health check results
$healthCheck = .\Get-SqlHealth.ps1 -ServerInstance "SQLSERVER01"
Write-StructuredLog -Message "SQL health check completed" -Severity Information -Properties @{
    Server = "SQLSERVER01"
    Status = "Success"
}
```

## Testing

### Unit Testing
Each script can be tested individually:
```powershell
# Test log cleanup in preview mode
.\Invoke-LogCleanup.ps1 -WhatIf

# Test Azure tagging without changes
.\Set-AzureVmTagsFromPolicy.ps1 -WhatIf

# Test SQL health check on localhost
.\Get-SqlHealth.ps1 -ServerInstance "localhost"
```

### Integration Testing
Test scripts together in a workflow:
```powershell
# 1. Check SQL health
.\Get-SqlHealth.ps1 -ServerInstance "SQLSERVER01" -CheckBackups

# 2. Clean logs if disk space is low
.\Invoke-LogCleanup.ps1 -AutoConfirm

# 3. Tag Azure resources
.\Set-AzureVmTagsFromPolicy.ps1
```

## Customization

### Adding New Patterns
To add new naming patterns to the Azure tagging script:
```powershell
$namingPatterns = @{
    'PROD-'   = @{ Environment = 'Production' }
    'CUSTOM-' = @{ YourTag = 'YourValue' }  # Add your pattern here
}
```

### Adjusting Retention
Modify default retention periods:
```powershell
param(
    [int]$IISRetentionDays = 60,  # Change from 30 to 60
    [int]$SSHRetentionDays = 180  # Change from 90 to 180
)
```

### Custom Health Checks
Add custom SQL queries to health check:
```powershell
$customQuery = @"
SELECT your_custom_metric FROM your_table
"@
$customResults = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $customQuery
```

## Troubleshooting

### Common Issues

**Module Not Found:**
```powershell
# Scripts auto-install required modules
# If issues persist, manually install:
Install-Module -Name SqlServer -Force
Install-Module -Name Az.Accounts -Force
Install-Module -Name Az.Compute -Force
```

**Permission Denied:**
```powershell
# Run PowerShell as Administrator for:
# - Log cleanup operations
# - SQL Server operations
# - Azure operations may require specific RBAC roles
```

**Azure Authentication:**
```powershell
# Clear cached credentials if authentication fails:
Clear-AzContext -Force
Connect-AzAccount
```

## Contributing

When creating new example scripts:
1. Follow the established parameter patterns
2. Include comprehensive comment-based help
3. Implement error handling
4. Add WhatIf support for destructive operations
5. Use color-coded output
6. Export results to CSV
7. Update this README

## License

See LICENSE file in repository root.
