# SQL Permissions Pipeline

Azure DevOps pipeline for automated SQL Server permissions management across multiple environments.

## Overview

This pipeline automates SQL Server role assignments and permissions management using a configuration-driven approach. It ensures consistent permissions across Dev/UAT/Prod environments while maintaining audit trails.

## Pipeline Files

### sql-permissions-pipeline.yml
**Purpose:** Azure DevOps YAML pipeline definition

**Stages:**
1. **Validation** - Validate configuration and connectivity
2. **Dry-Run** - Preview changes without applying
3. **Apply** - Execute permission changes
4. **Audit** - Log changes and verify results

**Trigger:** Manual or on configuration file changes

---

### SQL-Permissions-Orchestrator.ps1
**Purpose:** PowerShell orchestration script that applies permissions

**Features:**
- Configuration-driven role assignments
- Multi-server parallel execution
- Idempotent operations (safe to re-run)
- Comprehensive audit logging
- Rollback capability

---

## Configuration Structure

### permissions-config.json

```json
{
  "version": "1.0",
  "environments": {
    "DEV": {
      "servers": ["SQLDEV01", "SQLDEV02"],
      "roles": [
        {
          "database": "ApplicationDB",
          "role": "db_datareader",
          "members": ["DOMAIN\\AppServiceAccount", "DOMAIN\\ReportingUser"]
        },
        {
          "database": "ApplicationDB",
          "role": "db_datawriter",
          "members": ["DOMAIN\\AppServiceAccount"]
        }
      ]
    },
    "PROD": {
      "servers": ["SQLPROD01", "SQLPROD02"],
      "roles": [
        {
          "database": "ApplicationDB",
          "role": "db_datareader",
          "members": ["DOMAIN\\ProdAppService"]
        }
      ]
    }
  }
}
```

---

## Pipeline Architecture

```
┌──────────────────────────────────────────────────────────┐
│ Azure DevOps Pipeline                                    │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Stage 1: Validation                                    │
│  ├─ Validate JSON configuration                        │
│  ├─ Test SQL Server connectivity                       │
│  ├─ Verify service account permissions                 │
│  └─ Check database existence                           │
│                                                          │
│  Stage 2: Dry-Run (Preview)                            │
│  ├─ Compare current vs desired state                   │
│  ├─ Generate change report                             │
│  ├─ Identify additions/removals                        │
│  └─ Output preview to pipeline logs                    │
│                                                          │
│  Stage 3: Apply Changes                                │
│  ├─ Add users to roles                                 │
│  ├─ Remove users from roles (if configured)            │
│  ├─ Create logins if needed                            │
│  └─ Map logins to database users                       │
│                                                          │
│  Stage 4: Audit & Verification                         │
│  ├─ Query actual role memberships                      │
│  ├─ Compare with configuration                         │
│  ├─ Log all changes to audit table                     │
│  └─ Generate compliance report                         │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## Usage

### Run Pipeline Manually

1. Navigate to Azure DevOps Pipelines
2. Select "SQL-Permissions-Pipeline"
3. Click "Run pipeline"
4. Select parameters:
   - **Environment:** Dev, UAT, or Prod
   - **DryRun:** true (preview) or false (apply)
   - **ConfigPath:** Path to permissions-config.json

### Automated Trigger

Pipeline runs automatically when `permissions-config.json` is updated:

```yaml
trigger:
  branches:
    include:
    - main
  paths:
    include:
    - cicd-pipelines/sql-permissions-pipeline/config/permissions-config.json
```

---

## Pipeline Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `Environment` | Target environment | Dev, UAT, Prod |
| `DryRun` | Preview mode | true/false |
| `ConfigPath` | Config file path | config/permissions-config.json |
| `ServiceConnection` | Azure DevOps service connection | sql-automation-sp |
| `AuditDatabase` | Database for audit logs | AuditDB |

---

## Safety Features

### 1. Dry-Run Mode (Default)

```yaml
parameters:
- name: DryRun
  type: boolean
  default: true
  displayName: 'Dry Run (preview changes only)'
```

**Output Example:**
```
DRY-RUN MODE - No changes will be applied

Server: SQLPROD01
Database: ApplicationDB

Planned Changes:
  [+] Add DOMAIN\NewAppService to db_datareader
  [+] Add DOMAIN\NewAppService to db_datawriter
  [-] Remove DOMAIN\OldAppService from db_datareader

Total: 2 additions, 1 removal
```

### 2. Idempotent Operations

- Safe to run multiple times
- Only applies necessary changes
- Skips existing role memberships

### 3. Approval Gates

- **Production:** Requires manual approval from DBA team
- **UAT:** Requires team lead approval
- **Dev:** Runs automatically

### 4. Rollback Capability

```powershell
# Rollback script included
.\Rollback-SqlPermissions.ps1 -AuditId "12345" -Environment "PROD"
```

---

## Audit Logging

All permission changes are logged to an audit table:

### Audit Table Schema

```sql
CREATE TABLE dbo.SqlPermissionsAudit (
    AuditId INT IDENTITY(1,1) PRIMARY KEY,
    Timestamp DATETIME2 DEFAULT GETDATE(),
    Environment VARCHAR(50),
    ServerName VARCHAR(255),
    DatabaseName VARCHAR(255),
    RoleName VARCHAR(255),
    MemberName VARCHAR(255),
    Action VARCHAR(50),  -- 'ADD' or 'REMOVE'
    ExecutedBy VARCHAR(255),
    PipelineRunId VARCHAR(255),
    Success BIT,
    ErrorMessage NVARCHAR(MAX)
)
```

### Query Audit History

```sql
-- Recent permission changes
SELECT TOP 100 *
FROM dbo.SqlPermissionsAudit
ORDER BY Timestamp DESC

-- Changes by environment
SELECT Environment, COUNT(*) as ChangeCount
FROM dbo.SqlPermissionsAudit
WHERE Timestamp >= DATEADD(day, -30, GETDATE())
GROUP BY Environment
```

---

## Example Pipeline Run

```
Pipeline: SQL-Permissions-Pipeline
Environment: Production
DryRun: false
Triggered: Configuration change (permissions-config.json)
Started: 2026-01-07 10:30:00

Stage 1: Validation ✅
  ├─ Configuration valid (JSON schema OK)
  ├─ SQLPROD01: Connectivity OK
  ├─ SQLPROD02: Connectivity OK
  └─ All databases exist

Stage 2: Dry-Run ✅
  ├─ SQLPROD01.ApplicationDB: 2 changes planned
  ├─ SQLPROD02.ApplicationDB: 2 changes planned
  └─ Total: 4 changes across 2 servers

Stage 3: Apply Changes ✅
  ├─ SQLPROD01: Added DOMAIN\NewAppService to db_datareader
  ├─ SQLPROD01: Added DOMAIN\NewAppService to db_datawriter
  ├─ SQLPROD02: Added DOMAIN\NewAppService to db_datareader
  └─ SQLPROD02: Added DOMAIN\NewAppService to db_datawriter

Stage 4: Audit & Verification ✅
  ├─ Verified all role memberships
  ├─ Logged 4 changes to audit table
  ├─ Compliance report generated
  └─ Notification sent to DBA team

Duration: 3 minutes 45 seconds
Status: SUCCESS ✅
```

---

## Configuration Best Practices

### 1. Use Groups Instead of Individual Users

```json
{
  "role": "db_datareader",
  "members": [
    "DOMAIN\\AppReadOnlyGroup",  // ✅ Good - use AD groups
    "DOMAIN\\john.doe"            // ❌ Avoid - individual users
  ]
}
```

### 2. Separate Configs by Environment

```
config/
├─ permissions-dev.json
├─ permissions-uat.json
└─ permissions-prod.json
```

### 3. Version Control All Changes

- All config changes go through pull requests
- Require code review before merging
- Maintain change history in Git

### 4. Test in Dev First

- Always test configuration changes in Dev
- Validate in UAT before Prod
- Use Dry-Run mode to preview

---

## Troubleshooting

### "Login does not exist"
**Cause:** Windows login not created on SQL Server  
**Solution:** Pipeline will create login automatically if configured

### "User already exists in database"
**Cause:** User exists but not mapped to login  
**Solution:** Pipeline handles orphaned users automatically

### "Permission denied"
**Cause:** Service account lacks ALTER ROLE permission  
**Solution:** Grant service account db_securityadmin role

### "Configuration validation failed"
**Cause:** Invalid JSON or missing required fields  
**Solution:** Validate JSON syntax and schema

---

## Security Considerations

1. **Service Account Permissions:**
   - Minimum: `db_securityadmin` on target databases
   - Recommended: Dedicated automation account

2. **Audit Trail:**
   - All changes logged with timestamp and user
   - Audit logs retained for compliance (90+ days)

3. **Approval Process:**
   - Production changes require DBA approval
   - Configuration changes require code review

4. **Secrets Management:**
   - SQL credentials stored in Azure Key Vault
   - Service connection uses Azure AD authentication

---

## Related Documentation

- [sql-permissions-pipeline.yml](sql-permissions-pipeline.yml) - Pipeline definition
- [SQL-Permissions-Orchestrator.ps1](SQL-Permissions-Orchestrator.ps1) - Orchestration script
- [config/permissions-config.json](config/permissions-config.json) - Configuration file
- [../../docs/CICD-EXPLAINED.md](../../docs/CICD-EXPLAINED.md) - CI/CD patterns
- [../../docs/SECURITY-NOTES.md](../../docs/SECURITY-NOTES.md) - Security best practices

---

**Note:** This pipeline is production-tested and sanitized for portfolio use. Server names and account names are genericized.
