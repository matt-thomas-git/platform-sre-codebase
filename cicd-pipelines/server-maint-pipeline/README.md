# Server Maintenance Pipeline

Azure DevOps pipeline for orchestrated server maintenance operations.

## Overview

This pipeline automates routine server maintenance tasks across multiple environments (Dev/UAT/Prod), including service health checks, log cleanup, and post-maintenance validation.

## Pipeline Files

### Server-Maintenance-Pipeline.yml
**Purpose:** Azure DevOps YAML pipeline definition

**Stages:**
1. **Pre-Checks** - Validate server connectivity and service health
2. **Maintenance** - Execute maintenance tasks
3. **Post-Checks** - Verify services are running correctly
4. **Reporting** - Generate maintenance report

**Trigger:** Manual or scheduled (weekly)

---

### Server-Maintenance-Pipeline.ps1
**Purpose:** PowerShell orchestration script called by the pipeline

**Features:**
- Multi-server parallel execution
- Service health validation (IIS, SQL, SSRS, SSAS)
- Log cleanup (SQL error logs, IIS logs, SSH logs)
- Disk space monitoring
- Rollback on failure

---

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Azure DevOps Pipeline                                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Stage 1: Pre-Checks                                   │
│  ├─ Test server connectivity                           │
│  ├─ Check service health (IIS, SQL, etc.)             │
│  └─ Verify disk space                                  │
│                                                         │
│  Stage 2: Maintenance                                  │
│  ├─ Clean SQL error logs                              │
│  ├─ Clean IIS logs                                     │
│  ├─ Clean SSH/Bitvise logs                            │
│  └─ Restart services if needed                         │
│                                                         │
│  Stage 3: Post-Checks                                  │
│  ├─ Verify all services running                       │
│  ├─ Check disk space freed                            │
│  └─ Test application endpoints                         │
│                                                         │
│  Stage 4: Reporting                                    │
│  ├─ Generate maintenance summary                       │
│  ├─ Log to Azure Monitor                              │
│  └─ Send notifications                                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Configuration

### Server Lists

Server lists are defined in separate files by environment:

```
cicd-pipelines/server-maint-pipeline/
├─ servers-dev.json
├─ servers-uat.json
└─ servers-prod.json
```

**Example server-list.json:**
```json
{
  "servers": [
    {
      "name": "SQLSERVER01",
      "type": "SQL",
      "services": ["MSSQLSERVER", "SQLSERVERAGENT"],
      "logPaths": ["C:\\Program Files\\Microsoft SQL Server\\MSSQL15.MSSQLSERVER\\MSSQL\\Log"]
    },
    {
      "name": "WEBSERVER01",
      "type": "IIS",
      "services": ["W3SVC"],
      "logPaths": ["C:\\inetpub\\logs\\LogFiles"]
    }
  ]
}
```

---

## Usage

### Run Pipeline Manually

1. Navigate to Azure DevOps Pipelines
2. Select "Server-Maintenance-Pipeline"
3. Click "Run pipeline"
4. Select environment (Dev/UAT/Prod)
5. Review and approve

### Schedule Pipeline

```yaml
schedules:
- cron: "0 2 * * 0"  # Every Sunday at 2 AM
  displayName: Weekly Maintenance
  branches:
    include:
    - main
  always: true
```

---

## Pipeline Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `Environment` | Target environment | Dev, UAT, Prod |
| `DryRun` | Test mode without changes | true/false |
| `LogRetentionDays` | Days to keep logs | 30 |
| `ServiceConnection` | Azure service connection | platform-automation-sp |

---

## Safety Features

### 1. Dry-Run Mode
```yaml
parameters:
- name: DryRun
  type: boolean
  default: true
  displayName: 'Dry Run (no changes)'
```

### 2. Pre-Flight Checks
- Server connectivity validation
- Service health verification
- Disk space threshold checks

### 3. Rollback Capability
- Service state captured before maintenance
- Automatic rollback on failure
- Manual rollback option

### 4. Approval Gates
- Production requires manual approval
- UAT requires team lead approval
- Dev runs automatically

---

## Monitoring & Logging

### Pipeline Logs

All pipeline runs are logged to:
- Azure DevOps pipeline history
- Azure Monitor Log Analytics
- File-based logs on target servers

### Structured Logging

```powershell
Write-StructuredLog -Message "Starting maintenance" -Severity "INFO" -Component "ServerMaint"
Write-StructuredLog -Message "Cleaned 500MB of logs" -Severity "INFO" -Component "LogCleanup"
Write-StructuredLog -Message "Service restart failed" -Severity "ERROR" -Component "ServiceMgmt"
```

---

## Example Pipeline Run

```
Pipeline: Server-Maintenance-Pipeline
Environment: Production
Triggered: Manual (user@company.com)
Started: 2026-01-07 02:00:00

Stage 1: Pre-Checks ✅
  ├─ SQLSERVER01: Connectivity OK
  ├─ SQLSERVER01: Services running (MSSQLSERVER, SQLSERVERAGENT)
  ├─ WEBSERVER01: Connectivity OK
  └─ WEBSERVER01: Services running (W3SVC)

Stage 2: Maintenance ✅
  ├─ SQLSERVER01: Cleaned 1.2GB SQL error logs
  ├─ SQLSERVER01: Cleaned 450MB Bitvise logs
  ├─ WEBSERVER01: Cleaned 800MB IIS logs
  └─ Total space freed: 2.45GB

Stage 3: Post-Checks ✅
  ├─ SQLSERVER01: All services running
  ├─ WEBSERVER01: All services running
  └─ Application endpoints responding

Stage 4: Reporting ✅
  ├─ Maintenance summary generated
  ├─ Logged to Azure Monitor
  └─ Notification sent to team

Duration: 8 minutes 32 seconds
Status: SUCCESS ✅
```

---

## Troubleshooting

### Pipeline fails at Pre-Checks
**Cause:** Server connectivity or service health issues  
**Solution:** Investigate server status before running maintenance

### Log cleanup fails
**Cause:** Insufficient permissions or files in use  
**Solution:** Verify service account has delete permissions

### Services don't restart
**Cause:** Service dependencies or startup failures  
**Solution:** Check Windows Event Logs for service errors

---

## Best Practices

1. **Always test in Dev first** - Validate changes before UAT/Prod
2. **Use Dry-Run mode** - Test pipeline logic without making changes
3. **Schedule during maintenance windows** - Minimize user impact
4. **Monitor disk space** - Ensure adequate space before cleanup
5. **Review logs** - Check pipeline output for warnings

---

## Related Documentation

- [Server-Maintenance-Pipeline.yml](Server-Maintenance-Pipeline.yml) - Pipeline definition
- [Server-Maintenance-Pipeline.ps1](Server-Maintenance-Pipeline.ps1) - Orchestration script
- [../../docs/CICD-EXPLAINED.md](../../docs/CICD-EXPLAINED.md) - CI/CD patterns
- [../../automation/powershell/scripts/examples/Invoke-LogCleanup.ps1](../../automation/powershell/scripts/examples/Invoke-LogCleanup.ps1) - Log cleanup script

---

**Note:** This pipeline is production-tested and sanitized for portfolio use. Server names and configurations are genericized.
