# CI/CD Pipelines

This directory contains production Azure DevOps pipeline definitions and their supporting PowerShell scripts.

## Overview

These pipelines demonstrate enterprise-grade CI/CD practices for infrastructure automation, including:

- **Server Maintenance** - Automated log cleanup and disk space management
- **SQL Permissions** - Orchestrated permission deployment across environments
- **Log Cleanup** - Scheduled maintenance for SQL, IIS, and application logs

## Structure

```
cicd-pipelines/
├── README.md (this file)
├── server-maintenance-pipeline.yml    # Azure DevOps YAML pipeline
├── log-cleanup-pipeline.yml           # Azure DevOps YAML pipeline
├── sql-permissions-pipeline.yml       # Azure DevOps YAML pipeline
├── scripts/
│   ├── Server-Maintenance-Pipeline.ps1  # PowerShell script called by pipeline
│   └── LogCleanup-Pipeline.ps1          # PowerShell script called by pipeline
├── server-lists/
│   ├── DevServers.ps1                   # Development environment servers
│   ├── UATServers.ps1                   # UAT environment servers
│   └── ProductionServers.ps1            # Production environment servers
└── windows-updates/
    ├── README.md                        # Windows Update orchestration guide
    ├── WinUpdateLibrary.ps1             # Core update functions
    ├── DynatraceSDT.ps1                 # Dynatrace maintenance window automation
    ├── PreSteps.ps1                     # Pre-update health checks
    └── PostSteps.ps1                    # Post-update validation
```

## Pipelines

### 1. Server Maintenance Pipeline

**File:** `server-maintenance-pipeline.yml`  
**Script:** `scripts/Server-Maintenance-Pipeline.ps1`

**Purpose:**  
Automated server maintenance across multiple servers with configurable cleanup operations.

**Features:**
- ✅ **Multi-server support** - Process multiple servers in one run
- ✅ **Selective cleanup** - Choose which components to clean
- ✅ **Configurable retention** - Set retention days per cleanup type
- ✅ **Remote execution** - Uses PowerShell remoting for distributed operations
- ✅ **Progress tracking** - Detailed logging and reporting
- ✅ **Pipeline variables** - Exports results to Azure DevOps variables

**Cleanup Operations:**
1. **SQL Server Logs** - ERRORLOG and SQLAGENT logs
2. **IIS Logs** - Web server access logs
3. **Bitvise SSH Logs** - SSH server logs
4. **Temp Folders** - C:\Temp and C:\Windows\Temp
5. **SFTP Data** - Regular and archive SFTP files

**Parameters:**
```yaml
- serverListFile: 'custom'           # Or predefined server list
- customServers: 'SERVER1,SERVER2'   # Comma-separated server names
- selectAll: false                   # Enable all cleanup options
- cleanSQL: true                     # Clean SQL Server logs
- cleanIIS: true                     # Clean IIS logs
- cleanBitvise: false                # Clean Bitvise logs
- cleanTempFolders: true             # Clean temp folders
- cleanSFTP: false                   # Clean SFTP data
- cleanSFTPArchive: false            # Clean SFTP archives
- sqlRetentionDays: 0                # 0 = keep current only
- iisRetentionDays: 30               # Keep last 30 days
- bitviseRetentionDays: 90           # Keep last 90 days
- tempFolderRetentionDays: 0         # 0 = delete all
- sftpRetentionDays: 180             # Keep last 180 days
- sftpArchiveRetentionDays: 180      # Keep last 180 days
```

**Usage Example:**
```yaml
# In Azure DevOps, run the pipeline with:
- Server List: custom
- Custom Servers: WEBSERVER01,WEBSERVER02,SQLSERVER01
- Select All: false
- Clean SQL: true
- Clean IIS: true
- SQL Retention Days: 0
- IIS Retention Days: 30
```

**Output:**
- Total files deleted
- Total space freed (formatted as GB/MB/KB)
- Per-server breakdown
- Error count
- Azure DevOps pipeline variables set for downstream tasks

---

### 2. Log Cleanup Pipeline

**File:** `log-cleanup-pipeline.yml`  
**Script:** `scripts/LogCleanup-Pipeline.ps1`

**Purpose:**  
Scheduled log cleanup for SQL Server, IIS, and application logs.

**Features:**
- ✅ **Scheduled execution** - Runs on a schedule (e.g., weekly)
- ✅ **Multi-component cleanup** - SQL, IIS, Bitvise in one run
- ✅ **Retention policies** - Configurable per log type
- ✅ **Space reporting** - Shows space freed per server
- ✅ **Error handling** - Continues on errors, reports at end

**Typical Schedule:**
```yaml
schedules:
- cron: "0 2 * * 0"  # 2 AM every Sunday
  displayName: Weekly log cleanup
  branches:
    include:
    - main
  always: true
```

---

### 3. SQL Permissions Pipeline

**File:** `sql-permissions-pipeline.yml`

**Purpose:**  
Orchestrated deployment of SQL Server permissions across environments using the SQL Permissions Orchestrator.

**Features:**
- ✅ **Environment-aware** - Different configs for dev/uat/prod
- ✅ **Multi-platform** - AD, Azure AD, SQL Server, Azure SQL
- ✅ **Dry-run mode** - Preview changes before applying
- ✅ **Approval gates** - Require approval for production
- ✅ **Configuration-as-code** - JSON-based permission definitions
- ✅ **Audit trail** - JSON result exports

**Parameters:**
```yaml
- environment: 'dev'                    # dev, uat, staging, production
- operationType: 'all'                  # all, adGroupsOnly, azureADGroupsOnly, etc.
- dryRun: false                         # Preview mode
- autoConfirm: true                     # Skip interactive prompts
```

**Workflow:**
1. Checkout repository
2. Load configuration from `sql-automation/config/permissions-config.json`
3. Execute SQL-Permissions-Orchestrator.ps1
4. Create AD groups (if selected)
5. Create Azure AD groups (if selected)
6. Apply SQL Server permissions (if selected)
7. Apply Azure SQL permissions (if selected)
8. Export results to JSON
9. Set pipeline variables

---

## PowerShell Scripts

### Server-Maintenance-Pipeline.ps1

**Location:** `scripts/Server-Maintenance-Pipeline.ps1`

**Key Functions:**
- `Format-FileSize` - Converts bytes to human-readable format
- `Get-SafeConfirmation` - Handles interactive vs pipeline mode
- Remote script blocks for each cleanup type
- Multi-server orchestration with error handling

**Script Blocks:**
- `$sqlCleanupScript` - SQL Server log cleanup
- `$iisCleanupScript` - IIS log cleanup
- `$bitviseCleanupScript` - Bitvise SSH log cleanup
- `$tempCleanupScript` - Temp folder cleanup
- `$sftpCleanupScript` - SFTP data cleanup

**Error Handling:**
- Continues on individual server failures
- Tracks total errors
- Returns exit code 1 if any errors occurred
- Detailed error messages in output

---

### LogCleanup-Pipeline.ps1

**Location:** `scripts/LogCleanup-Pipeline.ps1`

Similar to Server-Maintenance-Pipeline.ps1 but optimized for scheduled execution with predefined settings.

---

## Best Practices

### 1. **Server Lists**

Create reusable server list files:

```powershell
# ServerLists/WebServers.ps1
@(
    "WEBSERVER01",
    "WEBSERVER02",
    "WEBSERVER03"
)
```

Reference in pipeline:
```yaml
parameters:
- name: serverListFile
  default: 'ServerLists/WebServers.ps1'
```

### 2. **Retention Policies**

Recommended retention periods:

| Log Type | Retention | Reason |
|----------|-----------|--------|
| SQL ERRORLOG | 0 days (current only) | SQL keeps numbered archives |
| IIS Logs | 30 days | Compliance requirement |
| Bitvise Logs | 90 days | Security audit trail |
| Temp Folders | 0 days | Safe to delete all |
| SFTP Data | 180 days | Business requirement |

### 3. **Pipeline Scheduling**

```yaml
schedules:
- cron: "0 2 * * 0"      # Weekly - Sunday 2 AM
  displayName: Weekly maintenance
  branches:
    include:
    - main
  always: true

- cron: "0 3 1 * *"      # Monthly - 1st day 3 AM
  displayName: Monthly deep clean
  branches:
    include:
    - main
  always: true
```

### 4. **Variable Groups**

Create Azure DevOps variable groups for reusable settings:

```yaml
variables:
- group: MaintenanceVG
  # Contains:
  # - DefaultSQLRetention: 0
  # - DefaultIISRetention: 30
  # - DefaultBitviseRetention: 90
```

### 5. **Approval Gates**

For production environments:

```yaml
stages:
- stage: Production
  jobs:
  - deployment: ProductionMaintenance
    environment: 'production'  # Requires approval
    strategy:
      runOnce:
        deploy:
          steps:
          - script: # maintenance tasks
```

## Monitoring & Alerting

### Pipeline Variables

All pipelines set Azure DevOps variables for downstream tasks:

```powershell
Write-Host "##vso[task.setvariable variable=ServerMaintenance.TotalFilesDeleted]$totalDeleted"
Write-Host "##vso[task.setvariable variable=ServerMaintenance.TotalSpaceFreed]$totalSpaceFreed"
Write-Host "##vso[task.setvariable variable=ServerMaintenance.TotalErrors]$totalErrors"
```

Use in subsequent tasks:

```yaml
- task: PowerShell@2
  inputs:
    targetType: 'inline'
    script: |
      $filesDeleted = "$(ServerMaintenance.TotalFilesDeleted)"
      $spaceFreed = "$(ServerMaintenance.TotalSpaceFreed)"
      Write-Host "Cleanup freed $spaceFreed by deleting $filesDeleted files"
```

### Notifications

Configure pipeline notifications:

```yaml
trigger:
  branches:
    include:
    - main

resources:
  webhooks:
  - webhook: TeamsNotification
    connection: TeamsWebhook
```

## Troubleshooting

### Common Issues

**Issue:** Pipeline times out  
**Solution:** Reduce number of servers or increase timeout:
```yaml
jobs:
- job: Maintenance
  timeoutInMinutes: 60  # Increase from default 30
```

**Issue:** Access denied on remote servers  
**Solution:** Ensure pipeline agent has appropriate permissions:
- Add agent service account to local Administrators group
- Enable PowerShell remoting: `Enable-PSRemoting -Force`

**Issue:** Cannot delete files in use  
**Solution:** Stop services before cleanup or exclude locked files

**Issue:** Script not found  
**Solution:** Verify repository checkout and script path:
```yaml
- checkout: infrastructure
  displayName: 'Checkout Infrastructure Repository'
```

## Security Considerations

### 1. **Credentials**

- Use Azure DevOps service connections
- Store sensitive values in variable groups (marked as secret)
- Never hardcode credentials in scripts

### 2. **Permissions**

- Principle of least privilege
- Separate service accounts for dev/prod
- Audit pipeline execution logs

### 3. **Approval Gates**

- Require manual approval for production
- Implement change management integration
- Log all approvals

## Example: Complete Pipeline Run

```
=== SERVER MAINTENANCE PIPELINE ===
Timestamp: 2026-01-04 02:00:00
Running User: PipelineAgent
Computer: BUILDSERVER01

Configuration:
  SQL Server Cleanup: True
  IIS Cleanup: True
  Auto Confirm: True

=== Processing Server: WEBSERVER01 ===
Server WEBSERVER01 is reachable

Processing SQL Server logs on WEBSERVER01...
SQL Server Results:
  Instances found: 1
  Files deleted: 15
  Space freed: 245.67 MB
  Errors: 0

Processing IIS logs on WEBSERVER01...
IIS Results:
  Sites found: 3
  Files deleted: 127
  Space freed: 1.23 GB
  Errors: 0

=== FINAL SUMMARY ===
Execution completed at: 2026-01-04 02:05:23
Total files deleted: 142
Total space freed: 1.48 GB
Total errors: 0

Operation completed successfully!
```

## Additional Resources

- [Azure DevOps Pipeline Documentation](https://docs.microsoft.com/en-us/azure/devops/pipelines/)
- [PowerShell Remoting Guide](https://docs.microsoft.com/en-us/powershell/scripting/learn/remoting/running-remote-commands)
- [YAML Pipeline Schema](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema)

## Version History

- **v1.0** - Initial server maintenance pipeline
- **v1.1** - Added SFTP cleanup support
- **v2.0** - Refactored to single-step approach
- **v2.1** - Added SQL Permissions orchestration
- **v3.0** - Configuration-as-code with JSON configs
