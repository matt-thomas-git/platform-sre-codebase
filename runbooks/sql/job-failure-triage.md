# SQL Agent Job Failure Triage

**Severity:** Medium-High  
**Estimated Time:** 10-20 minutes  
**Skills Required:** SQL Server Administration, T-SQL

## Overview

SQL Server Agent jobs automate critical tasks including backups, maintenance, ETL processes, and data synchronization. Job failures can impact data integrity, compliance, and business operations.

## Symptoms

- SQL Agent job failure alerts
- Missing expected data in target systems
- Backup compliance violations
- Monitoring alerts for failed jobs
- Event ID 208 in Application Event Log

## Prerequisites

- SQL Server Management Studio (SSMS) or sqlcmd access
- SQL Agent permissions (SQLAgentOperatorRole or sysadmin)
- Access to job history and error logs

## Investigation Steps

### 1. Identify Failed Job Details

```sql
-- Get recent job failures (last 24 hours)
SELECT 
    j.name AS JobName,
    h.step_name AS StepName,
    h.run_date,
    h.run_time,
    h.run_duration,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
    END AS Status,
    h.message AS ErrorMessage
FROM msdb.dbo.sysjobs j
INNER JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
WHERE h.run_status = 0  -- Failed
    AND h.run_date >= CONVERT(INT, CONVERT(VARCHAR(8), DATEADD(DAY, -1, GETDATE()), 112))
ORDER BY h.run_date DESC, h.run_time DESC;
```

### 2. Get Detailed Job Configuration

```sql
-- Get job details and schedule
SELECT 
    j.name AS JobName,
    j.enabled AS JobEnabled,
    j.description,
    s.name AS ScheduleName,
    s.enabled AS ScheduleEnabled,
    CASE s.freq_type
        WHEN 1 THEN 'Once'
        WHEN 4 THEN 'Daily'
        WHEN 8 THEN 'Weekly'
        WHEN 16 THEN 'Monthly'
        WHEN 32 THEN 'Monthly relative'
        WHEN 64 THEN 'When SQL Server Agent starts'
        WHEN 128 THEN 'Start whenever CPUs become idle'
    END AS Frequency,
    s.active_start_time,
    s.active_end_time
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
LEFT JOIN msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
WHERE j.name = '<JOB_NAME>';
```

### 3. Review Job Steps

```sql
-- Get all steps for a specific job
SELECT 
    step_id,
    step_name,
    subsystem,
    command,
    database_name,
    on_success_action,
    on_fail_action,
    retry_attempts,
    retry_interval
FROM msdb.dbo.sysjobsteps
WHERE job_id = (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = '<JOB_NAME>')
ORDER BY step_id;
```

### 4. Check SQL Server Error Log

```sql
-- Search error log for job-related errors
EXEC sp_readerrorlog 0, 1, 'Job', '<JOB_NAME>';

-- Check for specific error messages
EXEC sp_readerrorlog 0, 1, 'failed', NULL, NULL, NULL, 'DESC';
```

## Common Failure Scenarios

### 1. Backup Job Failures

**Common Causes:**
- Insufficient disk space
- Network path unavailable
- Permissions issues
- Database in use/locked

**Investigation:**
```sql
-- Check backup history
SELECT 
    database_name,
    backup_start_date,
    backup_finish_date,
    DATEDIFF(MINUTE, backup_start_date, backup_finish_date) AS DurationMinutes,
    backup_size / 1024 / 1024 AS BackupSizeMB,
    compressed_backup_size / 1024 / 1024 AS CompressedSizeMB,
    physical_device_name,
    type,
    CASE type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Log'
    END AS BackupType
FROM msdb.dbo.backupset
WHERE database_name = '<DATABASE_NAME>'
ORDER BY backup_start_date DESC;
```

**Resolution:**
```powershell
# Check disk space on backup location
Get-PSDrive | Where-Object {$_.Provider -like "*FileSystem*"} | 
    Select-Object Name, @{N="UsedGB";E={[math]::Round($_.Used/1GB,2)}}, 
                  @{N="FreeGB";E={[math]::Round($_.Free/1GB,2)}}

# Test network path
Test-Path "\\backup-server\sql-backups"
```

### 2. Index Maintenance Failures

**Common Causes:**
- Long-running queries blocking maintenance
- Insufficient TempDB space
- Transaction log full
- Timeout issues

**Investigation:**
```sql
-- Check for blocking
SELECT 
    blocking_session_id,
    session_id,
    wait_type,
    wait_time,
    wait_resource,
    command,
    status
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0;

-- Check transaction log space
DBCC SQLPERF(LOGSPACE);
```

### 3. ETL/Data Sync Failures

**Common Causes:**
- Source/destination connectivity issues
- Data type mismatches
- Constraint violations
- Timeout on large datasets

**Investigation:**
```sql
-- Check linked server connectivity
EXEC sp_testlinkedserver 'LINKED_SERVER_NAME';

-- Test query on linked server
SELECT TOP 1 * FROM [LINKED_SERVER].[Database].[Schema].[Table];
```

### 4. SSIS Package Failures

**Common Causes:**
- Package configuration issues
- Connection string problems
- File path not found
- Permissions issues

**Investigation:**
```sql
-- Check SSIS execution history
SELECT 
    execution_id,
    folder_name,
    project_name,
    package_name,
    status,
    start_time,
    end_time,
    DATEDIFF(MINUTE, start_time, end_time) AS DurationMinutes
FROM SSISDB.catalog.executions
WHERE package_name = '<PACKAGE_NAME>'
ORDER BY start_time DESC;

-- Get detailed error messages
SELECT 
    operation_id,
    message_time,
    message_type,
    message
FROM SSISDB.catalog.operation_messages
WHERE operation_id = <EXECUTION_ID>
    AND message_type IN (120, 130)  -- Errors and warnings
ORDER BY message_time DESC;
```

## Immediate Remediation

### 1. Restart Failed Job

```sql
-- Start job manually
EXEC msdb.dbo.sp_start_job @job_name = '<JOB_NAME>';

-- Start job at specific step
EXEC msdb.dbo.sp_start_job 
    @job_name = '<JOB_NAME>',
    @step_name = '<STEP_NAME>';
```

### 2. Disable Job Temporarily

```sql
-- Disable job to prevent repeated failures
EXEC msdb.dbo.sp_update_job 
    @job_name = '<JOB_NAME>',
    @enabled = 0;

-- Re-enable after fix
EXEC msdb.dbo.sp_update_job 
    @job_name = '<JOB_NAME>',
    @enabled = 1;
```

### 3. Modify Job Retry Logic

```sql
-- Update step to retry on failure
EXEC msdb.dbo.sp_update_jobstep
    @job_name = '<JOB_NAME>',
    @step_id = 1,
    @retry_attempts = 3,
    @retry_interval = 5;  -- 5 minutes
```

## Resolution Steps by Job Type

### Backup Jobs

```sql
-- Manual backup if job failed
BACKUP DATABASE [DatabaseName]
TO DISK = '\\backup-server\sql-backups\DatabaseName_Manual.bak'
WITH COMPRESSION, CHECKSUM, STATS = 10;

-- Verify backup
RESTORE VERIFYONLY 
FROM DISK = '\\backup-server\sql-backups\DatabaseName_Manual.bak';
```

### Index Maintenance

```sql
-- Run index maintenance manually with reduced scope
ALTER INDEX ALL ON [Schema].[TableName] 
REORGANIZE;  -- Less intensive than REBUILD

-- Or rebuild specific index
ALTER INDEX [IX_IndexName] ON [Schema].[TableName] 
REBUILD WITH (ONLINE = ON, MAXDOP = 2);
```

### Data Sync/ETL

```sql
-- Run sync query manually to test
BEGIN TRANSACTION;

-- Your sync logic here
INSERT INTO TargetTable (Col1, Col2)
SELECT Col1, Col2 
FROM SourceTable
WHERE LastModified > @LastSyncTime;

-- Verify row count
SELECT @@ROWCOUNT AS RowsAffected;

ROLLBACK;  -- Or COMMIT if verified
```

## Long-Term Solutions

### 1. Implement Job Monitoring

```sql
-- Create alert for job failures
USE msdb;
GO

EXEC sp_add_alert 
    @name = N'Job Failure Alert',
    @message_id = 0,
    @severity = 0,
    @enabled = 1,
    @delay_between_responses = 0,
    @include_event_description_in = 1,
    @notification_message = N'SQL Agent job has failed',
    @category_name = N'[Uncategorized]',
    @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add notification
EXEC sp_add_notification 
    @alert_name = N'Job Failure Alert',
    @operator_name = N'DBA Team',
    @notification_method = 1;  -- Email
```

### 2. Improve Job Logging

```sql
-- Add logging step to job
EXEC msdb.dbo.sp_add_jobstep
    @job_name = '<JOB_NAME>',
    @step_name = 'Log Execution',
    @subsystem = 'TSQL',
    @command = '
        INSERT INTO DBA.dbo.JobExecutionLog (JobName, StartTime, Status)
        VALUES (''<JOB_NAME>'', GETDATE(), ''Started'');
    ',
    @on_success_action = 3,  -- Go to next step
    @on_fail_action = 2;     -- Quit with failure
```

### 3. Optimize Job Schedules

```sql
-- Adjust schedule to avoid conflicts
EXEC msdb.dbo.sp_update_schedule
    @name = '<SCHEDULE_NAME>',
    @active_start_time = 020000;  -- 2:00 AM instead of peak hours
```

### 4. Add Error Handling

```sql
-- Example job step with error handling
BEGIN TRY
    -- Your job logic here
    EXEC sp_YourProcedure;
    
    -- Log success
    INSERT INTO DBA.dbo.JobExecutionLog (JobName, Status, Message)
    VALUES ('JobName', 'Success', 'Completed successfully');
END TRY
BEGIN CATCH
    -- Log error
    INSERT INTO DBA.dbo.JobExecutionLog (JobName, Status, Message, ErrorNumber, ErrorMessage)
    VALUES (
        'JobName', 
        'Failed', 
        'Error occurred',
        ERROR_NUMBER(),
        ERROR_MESSAGE()
    );
    
    -- Re-throw error to fail job
    THROW;
END CATCH;
```

## Prevention

### Daily Checks

```sql
-- Daily job health check
SELECT 
    j.name AS JobName,
    CASE 
        WHEN h.run_status = 1 THEN 'Success'
        WHEN h.run_status = 0 THEN 'Failed'
        ELSE 'Other'
    END AS LastRunStatus,
    msdb.dbo.agent_datetime(h.run_date, h.run_time) AS LastRunTime,
    j.enabled AS JobEnabled,
    s.enabled AS ScheduleEnabled
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
    AND h.instance_id = (
        SELECT MAX(instance_id)
        FROM msdb.dbo.sysjobhistory
        WHERE job_id = j.job_id AND step_id = 0
    )
LEFT JOIN msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
LEFT JOIN msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
WHERE j.enabled = 1
ORDER BY LastRunStatus, j.name;
```

### Weekly Review

- Review job execution times for trends
- Check for jobs consistently taking longer
- Verify backup retention compliance
- Review and clean up old job history

## Escalation

**Escalate to Database Team if:**
- Job failure impacts production data
- Unable to identify root cause within 30 minutes
- Requires code changes to stored procedures
- Recurring failures (>3 times in 24 hours)

**Escalate to Application Team if:**
- ETL/data sync failures affecting applications
- SSIS package errors
- Business logic issues in job steps

## Post-Incident

### Documentation

1. Record incident details:
   - Job name and failure time
   - Error messages
   - Root cause identified
   - Resolution steps taken
   - Time to resolution

2. Update runbook if new scenario

3. Create knowledge base article for recurring issues

### Follow-Up Actions

- [ ] Review job configuration for optimization
- [ ] Implement additional monitoring if needed
- [ ] Schedule code review for complex jobs
- [ ] Update job documentation
- [ ] Test job in non-production environment

## References

- [SQL Server Agent Jobs](https://docs.microsoft.com/en-us/sql/ssms/agent/sql-server-agent)
- [Troubleshooting SQL Server Agent](https://docs.microsoft.com/en-us/sql/ssms/agent/troubleshoot-multiserver-jobs-that-use-proxies)
- Internal Wiki: SQL Server Job Standards

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2024-01-15 | Platform SRE Team | Initial version |
| 2024-08-10 | Platform SRE Team | Added SSIS troubleshooting |
