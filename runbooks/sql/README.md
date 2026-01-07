# SQL Server Runbooks

Operational runbooks for SQL Server troubleshooting, maintenance, and incident response.

## Overview

This directory contains step-by-step runbooks for common SQL Server operational tasks, performance troubleshooting, and incident response procedures. These runbooks are designed for DBAs, on-call engineers, and operations teams.

## Available Runbooks

### tempdb-growth.md
**Purpose:** Troubleshoot and resolve TempDB growth issues

**When to Use:**
- TempDB consuming excessive disk space
- Disk space alerts on TempDB drive
- Performance degradation due to TempDB
- TempDB autogrowth events

**Key Steps:**
1. Identify queries causing TempDB growth
2. Kill long-running transactions
3. Shrink TempDB files (if safe)
4. Implement preventive measures

---

### job-failure-triage.md
**Purpose:** Investigate and resolve SQL Agent job failures

**When to Use:**
- SQL Agent job failure alerts
- Scheduled maintenance not completing
- Backup job failures
- ETL/data load failures

**Key Steps:**
1. Review job history and error messages
2. Check job step details
3. Investigate root cause
4. Implement fix and rerun

---

## Runbook Categories

### 🔥 Performance & Troubleshooting

**Topics Covered:**
- Slow query investigation
- Blocking and deadlocks
- High CPU usage
- Memory pressure
- TempDB contention
- Index fragmentation

**Example Scenarios:**
- Application timeout errors
- Queries running slower than normal
- Blocking chains affecting users
- Out of memory errors

---

### 💾 Backup & Recovery

**Topics Covered:**
- Backup job failures
- Restore procedures
- Point-in-time recovery
- Backup verification
- Transaction log management

**Example Scenarios:**
- Backup job failed
- Need to restore database
- Transaction log full
- Verify backup integrity

---

### 🔧 Maintenance & Operations

**Topics Covered:**
- Index maintenance
- Statistics updates
- DBCC CHECKDB
- Log file management
- Database shrink operations

**Example Scenarios:**
- Weekly maintenance tasks
- Index rebuild needed
- Database integrity checks
- Log file growth issues

---

### 🔐 Security & Permissions

**Topics Covered:**
- User access issues
- Permission troubleshooting
- Login failures
- Orphaned users
- Role membership audits

**Example Scenarios:**
- User can't access database
- Permission denied errors
- Login failures after migration
- Audit user permissions

---

### 📊 Monitoring & Alerting

**Topics Covered:**
- SQL Agent alerts
- Performance counter monitoring
- Wait statistics analysis
- Query store usage
- Extended events

**Example Scenarios:**
- Configure alerting
- Analyze wait statistics
- Identify expensive queries
- Monitor resource usage

---

## Common SQL Server Queries

### Performance Troubleshooting

```sql
-- Find currently running queries
SELECT 
    session_id,
    status,
    command,
    cpu_time,
    total_elapsed_time,
    reads,
    writes,
    text
FROM sys.dm_exec_requests
CROSS APPLY sys.dm_exec_sql_text(sql_handle)
WHERE session_id > 50
ORDER BY cpu_time DESC;

-- Find blocking chains
SELECT 
    blocking_session_id,
    session_id,
    wait_type,
    wait_time,
    wait_resource
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0;

-- Top queries by CPU
SELECT TOP 20
    qs.execution_count,
    qs.total_worker_time / qs.execution_count AS avg_cpu_time,
    qs.total_elapsed_time / qs.execution_count AS avg_elapsed_time,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset)/2) + 1) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY qs.total_worker_time / qs.execution_count DESC;
```

### TempDB Investigation

```sql
-- TempDB space usage by session
SELECT 
    session_id,
    SUM(user_objects_alloc_page_count) * 8 / 1024 AS user_objects_mb,
    SUM(internal_objects_alloc_page_count) * 8 / 1024 AS internal_objects_mb,
    SUM(user_objects_alloc_page_count + internal_objects_alloc_page_count) * 8 / 1024 AS total_mb
FROM sys.dm_db_session_space_usage
GROUP BY session_id
HAVING SUM(user_objects_alloc_page_count + internal_objects_alloc_page_count) > 0
ORDER BY total_mb DESC;

-- TempDB file usage
SELECT 
    name,
    physical_name,
    size * 8 / 1024 AS size_mb,
    FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024 AS used_mb,
    (size - FILEPROPERTY(name, 'SpaceUsed')) * 8 / 1024 AS free_mb
FROM sys.database_files
WHERE database_id = 2;
```

### Backup Verification

```sql
-- Recent backup history
SELECT 
    database_name,
    backup_start_date,
    backup_finish_date,
    DATEDIFF(MINUTE, backup_start_date, backup_finish_date) AS duration_minutes,
    backup_size / 1024 / 1024 AS backup_size_mb,
    type,
    CASE type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Log'
    END AS backup_type
FROM msdb.dbo.backupset
WHERE database_name = 'YourDatabase'
ORDER BY backup_start_date DESC;

-- Databases without recent backups
SELECT 
    d.name,
    MAX(b.backup_finish_date) AS last_backup_date,
    DATEDIFF(DAY, MAX(b.backup_finish_date), GETDATE()) AS days_since_backup
FROM sys.databases d
LEFT JOIN msdb.dbo.backupset b ON d.name = b.database_name
WHERE d.database_id > 4  -- Exclude system databases
GROUP BY d.name
HAVING MAX(b.backup_finish_date) < DATEADD(DAY, -1, GETDATE())
    OR MAX(b.backup_finish_date) IS NULL;
```

### SQL Agent Jobs

```sql
-- Recent job failures
SELECT 
    j.name AS job_name,
    h.run_date,
    h.run_time,
    h.run_duration,
    h.message
FROM msdb.dbo.sysjobhistory h
INNER JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
WHERE h.run_status = 0  -- Failed
    AND h.step_id = 0   -- Job outcome
ORDER BY h.run_date DESC, h.run_time DESC;

-- Currently running jobs
SELECT 
    j.name,
    ja.start_execution_date,
    DATEDIFF(MINUTE, ja.start_execution_date, GETDATE()) AS running_minutes
FROM msdb.dbo.sysjobactivity ja
INNER JOIN msdb.dbo.sysjobs j ON ja.job_id = j.job_id
WHERE ja.start_execution_date IS NOT NULL
    AND ja.stop_execution_date IS NULL;
```

---

## Common PowerShell Commands

### SQL Server Management

```powershell
# Get SQL Server services status
Get-Service | Where-Object {$_.Name -like "MSSQL*" -or $_.Name -like "SQLAgent*"}

# Restart SQL Server service
Restart-Service -Name "MSSQLSERVER" -Force

# Run SQL query
Invoke-Sqlcmd -ServerInstance "SQLSERVER01" -Database "master" -Query "SELECT @@VERSION"

# Get database sizes
Invoke-Sqlcmd -ServerInstance "SQLSERVER01" -Query @"
SELECT 
    name,
    (size * 8 / 1024) AS size_mb
FROM sys.master_files
WHERE database_id > 4
ORDER BY size DESC
"@
```

### Backup Operations

```powershell
# Backup database
Backup-SqlDatabase -ServerInstance "SQLSERVER01" -Database "ApplicationDB" -BackupFile "C:\Backups\ApplicationDB.bak"

# Restore database
Restore-SqlDatabase -ServerInstance "SQLSERVER01" -Database "ApplicationDB" -BackupFile "C:\Backups\ApplicationDB.bak" -ReplaceDatabase

# Verify backup
Test-SqlDatabaseBackup -ServerInstance "SQLSERVER01" -BackupFile "C:\Backups\ApplicationDB.bak"
```

---

## Troubleshooting Quick Reference

### High CPU Usage

1. Identify expensive queries (see query above)
2. Check for missing indexes
3. Update statistics
4. Review execution plans
5. Consider query optimization

### Blocking Issues

1. Identify blocking chain (see query above)
2. Review what blocked session is doing
3. Kill blocking session if appropriate: `KILL [session_id]`
4. Investigate root cause
5. Implement application changes

### TempDB Full

1. Identify sessions using TempDB (see query above)
2. Kill sessions with excessive usage
3. Restart SQL Server if needed
4. Increase TempDB size
5. Add more TempDB files

### Backup Failures

1. Check SQL Agent job history
2. Review error messages
3. Verify disk space
4. Check backup destination accessibility
5. Test backup manually

### Transaction Log Full

1. Check log space usage: `DBCC SQLPERF(LOGSPACE)`
2. Backup transaction log
3. Investigate long-running transactions
4. Check replication/mirroring status
5. Shrink log file if appropriate

---

## Best Practices

### 1. Investigation

- ✅ Gather all error messages
- ✅ Check SQL Server error log
- ✅ Review Windows Event Log
- ✅ Document current state
- ✅ Identify recent changes

### 2. Resolution

- ✅ Test fix in non-production first
- ✅ Have rollback plan
- ✅ Communicate with stakeholders
- ✅ Document actions taken
- ✅ Verify resolution

### 3. Prevention

- ✅ Implement monitoring
- ✅ Set up alerts
- ✅ Schedule regular maintenance
- ✅ Review and optimize queries
- ✅ Conduct post-incident reviews

### 4. Documentation

- ✅ Update runbooks with learnings
- ✅ Document workarounds
- ✅ Share knowledge with team
- ✅ Create KB articles
- ✅ Update monitoring

---

## Emergency Contacts

### Escalation Path

1. **Level 1:** On-call DBA
2. **Level 2:** Senior DBA / Database Team Lead
3. **Level 3:** Database Architect / Vendor Support

### When to Escalate

- Data corruption detected
- Unable to restore service within SLA
- Security breach suspected
- Unfamiliar error messages
- Multiple systems affected

---

## Related Documentation

- [SQL Server Documentation](https://docs.microsoft.com/en-us/sql/sql-server/)
- [../../automation/powershell/scripts/examples/Get-SqlHealth.ps1](../../automation/powershell/scripts/examples/Get-SqlHealth.ps1) - SQL health check script
- [../../docs/LESSONS-LEARNED.md](../../docs/LESSONS-LEARNED.md) - Production incident learnings
- [../../cicd-pipelines/sql-permissions-pipeline/](../../cicd-pipelines/sql-permissions-pipeline/) - SQL permissions automation

---

**Note:** These runbooks are based on real production scenarios and have been sanitized for portfolio use.
