# TempDB Growth Investigation and Remediation

**Severity:** High  
**Estimated Time:** 15-30 minutes  
**Skills Required:** SQL Server Administration, T-SQL

## Overview

TempDB is a system database used for temporary objects, sorting, and row versioning. Uncontrolled growth can lead to disk space exhaustion and SQL Server performance degradation.

## Symptoms

- Disk space alerts on SQL Server drive
- TempDB consuming excessive disk space (>80% of allocated space)
- SQL Server performance degradation
- Application timeouts or slow queries
- Event ID 1105 (disk space errors) in SQL Server logs

## Prerequisites

- SQL Server Management Studio (SSMS) or sqlcmd access
- Sysadmin or appropriate permissions on SQL Server instance
- RDP/console access to SQL Server

## Investigation Steps

### 1. Check TempDB Size and Usage

```sql
-- Check TempDB file sizes and space usage
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    name AS LogicalName,
    physical_name AS PhysicalName,
    size * 8 / 1024 AS SizeMB,
    CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) * 8 / 1024 AS UsedMB,
    (size * 8 / 1024) - (CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) * 8 / 1024) AS FreeMB,
    CAST(CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) * 100.0 / size AS DECIMAL(5,2)) AS PercentUsed
FROM sys.master_files
WHERE database_id = DB_ID('tempdb')
ORDER BY file_id;
```

**Expected Output:**
- TempDB data files (typically 4-8 files)
- Log file
- Size, used space, and percentage

**Action:** Note files with >80% usage

### 2. Identify Top Space Consumers

```sql
-- Find sessions using the most TempDB space
SELECT 
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    t.text AS query_text,
    tsu.user_objects_alloc_page_count * 8 / 1024 AS UserObjectsMB,
    tsu.internal_objects_alloc_page_count * 8 / 1024 AS InternalObjectsMB,
    (tsu.user_objects_alloc_page_count + tsu.internal_objects_alloc_page_count) * 8 / 1024 AS TotalMB
FROM sys.dm_db_session_space_usage tsu
INNER JOIN sys.dm_exec_sessions s ON tsu.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(s.most_recent_sql_handle) t
WHERE (tsu.user_objects_alloc_page_count + tsu.internal_objects_alloc_page_count) > 0
ORDER BY TotalMB DESC;
```

**What to Look For:**
- Sessions consuming >1GB of TempDB
- Long-running queries
- Batch jobs or ETL processes
- Queries with large sorts or hash operations

### 3. Check for Long-Running Transactions

```sql
-- Find active transactions in TempDB
SELECT 
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    t.text AS query_text,
    r.start_time,
    DATEDIFF(MINUTE, r.start_time, GETDATE()) AS RunningMinutes,
    r.status,
    r.command,
    r.wait_type,
    r.wait_time / 1000 AS WaitSeconds
FROM sys.dm_exec_requests r
INNER JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.database_id = DB_ID('tempdb')
ORDER BY RunningMinutes DESC;
```

### 4. Check TempDB Configuration

```sql
-- Verify TempDB file configuration
SELECT 
    name,
    size * 8 / 1024 AS CurrentSizeMB,
    max_size * 8 / 1024 AS MaxSizeMB,
    growth,
    is_percent_growth,
    CASE 
        WHEN is_percent_growth = 1 THEN CAST(growth AS VARCHAR) + '%'
        ELSE CAST(growth * 8 / 1024 AS VARCHAR) + ' MB'
    END AS GrowthSetting
FROM sys.master_files
WHERE database_id = DB_ID('tempdb');
```

**Best Practice Check:**
- ✅ Multiple data files (1 per CPU core, max 8)
- ✅ All files same size (uniform extent allocation)
- ✅ Fixed growth in MB (not percentage)
- ✅ Autogrowth set to reasonable size (512MB-1GB)

## Common Causes

### 1. Large Sort Operations
**Symptoms:** Queries with ORDER BY, GROUP BY, DISTINCT on large datasets

**Query to Identify:**
```sql
SELECT 
    qs.execution_count,
    qs.total_elapsed_time / 1000000 AS TotalElapsedSeconds,
    qs.total_worker_time / 1000000 AS TotalCPUSeconds,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset)/2) + 1) AS QueryText
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
WHERE qt.text LIKE '%ORDER BY%' OR qt.text LIKE '%GROUP BY%'
ORDER BY qs.total_elapsed_time DESC;
```

### 2. Index Rebuilds/Reorganizations
**Symptoms:** Maintenance jobs running, high TempDB usage during maintenance windows

**Check:**
```sql
-- Check for running index maintenance
SELECT 
    session_id,
    command,
    percent_complete,
    estimated_completion_time / 1000 / 60 AS EstimatedMinutesRemaining,
    start_time
FROM sys.dm_exec_requests
WHERE command LIKE '%INDEX%' OR command LIKE '%DBCC%';
```

### 3. Version Store Growth
**Symptoms:** Read Committed Snapshot Isolation (RCSI) enabled, long-running transactions

**Check:**
```sql
-- Check version store size
SELECT 
    SUM(version_store_reserved_page_count) * 8 / 1024 AS VersionStoreMB,
    SUM(user_object_reserved_page_count) * 8 / 1024 AS UserObjectsMB,
    SUM(internal_object_reserved_page_count) * 8 / 1024 AS InternalObjectsMB
FROM sys.dm_db_file_space_usage;
```

### 4. Statistics Updates
**Symptoms:** Auto-update statistics running on large tables

## Immediate Remediation

### Option 1: Kill Problematic Sessions (Use with Caution)

```sql
-- Review session details first
SELECT 
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    t.text
FROM sys.dm_exec_sessions s
OUTER APPLY sys.dm_exec_sql_text(s.most_recent_sql_handle) t
WHERE s.session_id = <SESSION_ID>;

-- Kill the session (coordinate with application team first!)
KILL <SESSION_ID>;
```

**⚠️ WARNING:** Only kill sessions after:
1. Identifying the query and its purpose
2. Coordinating with application/development team
3. Documenting the decision

### Option 2: Shrink TempDB (Temporary Relief)

```sql
-- Shrink TempDB data files (requires restart for full effect)
USE tempdb;
GO

DBCC SHRINKFILE (tempdev, 1024);  -- Shrink to 1GB
DBCC SHRINKFILE (temp2, 1024);
DBCC SHRINKFILE (temp3, 1024);
DBCC SHRINKFILE (temp4, 1024);
GO
```

**Note:** TempDB shrink is limited while SQL Server is running. For full shrink:
1. Stop SQL Server service
2. Start SQL Server with trace flag -T3608 (recovery only)
3. Shrink TempDB
4. Restart SQL Server normally

### Option 3: Add Disk Space (If Available)

```powershell
# Extend disk in Azure (PowerShell)
$vm = Get-AzVM -ResourceGroupName "RG-SQL-PROD" -Name "SQL-SERVER-01"
$disk = Get-AzDisk -ResourceGroupName "RG-SQL-PROD" -DiskName "SQL-DATA-DISK"
$disk.DiskSizeGB = 512  # Increase size
Update-AzDisk -ResourceGroupName "RG-SQL-PROD" -Disk $disk -DiskName $disk.Name

# Extend volume in Windows
# Open Disk Management → Extend Volume
```

## Long-Term Solutions

### 1. Optimize TempDB Configuration

```sql
-- Recommended configuration for production SQL Server
-- Execute during maintenance window

-- Set all TempDB files to same size
ALTER DATABASE tempdb MODIFY FILE (NAME = tempdev, SIZE = 8192MB, FILEGROWTH = 512MB);
ALTER DATABASE tempdb MODIFY FILE (NAME = temp2, SIZE = 8192MB, FILEGROWTH = 512MB);
ALTER DATABASE tempdb MODIFY FILE (NAME = temp3, SIZE = 8192MB, FILEGROWTH = 512MB);
ALTER DATABASE tempdb MODIFY FILE (NAME = temp4, SIZE = 8192MB, FILEGROWTH = 512MB);

-- Set log file
ALTER DATABASE tempdb MODIFY FILE (NAME = templog, SIZE = 2048MB, FILEGROWTH = 512MB);
```

**Best Practices:**
- Initial size: 8GB per file (adjust based on workload)
- Growth: 512MB-1GB fixed increments
- Number of files: 1 per CPU core (max 8 for most workloads)
- All files same size for optimal performance

### 2. Move TempDB to Faster Storage

```sql
-- Move TempDB to SSD/NVMe storage
-- Requires SQL Server restart

ALTER DATABASE tempdb MODIFY FILE (
    NAME = tempdev, 
    FILENAME = 'T:\TempDB\tempdb.mdf'
);

ALTER DATABASE tempdb MODIFY FILE (
    NAME = temp2, 
    FILENAME = 'T:\TempDB\tempdb_2.ndf'
);

-- Repeat for all files
-- Restart SQL Server to apply changes
```

### 3. Query Optimization

Work with development team to optimize queries:

```sql
-- Add missing indexes
-- Example: Create index to avoid sorts
CREATE NONCLUSTERED INDEX IX_Orders_OrderDate 
ON dbo.Orders (OrderDate DESC)
INCLUDE (CustomerID, TotalAmount);

-- Update statistics
UPDATE STATISTICS dbo.LargeTable WITH FULLSCAN;

-- Review execution plans for:
-- - Table scans on large tables
-- - Hash joins/sorts
-- - Missing indexes
```

### 4. Implement Monitoring

```sql
-- Create alert for TempDB space usage
-- SQL Server Agent Alert
USE msdb;
GO

EXEC sp_add_alert 
    @name = N'TempDB Space Alert',
    @message_id = 0,
    @severity = 0,
    @enabled = 1,
    @delay_between_responses = 900,  -- 15 minutes
    @include_event_description_in = 1,
    @category_name = N'[Uncategorized]',
    @performance_condition = N'SQLServer:Databases|Data File(s) Size (KB)|tempdb|>|8388608';  -- 8GB
```

## Prevention

### Daily Monitoring

```sql
-- Daily TempDB health check query
SELECT 
    GETDATE() AS CheckTime,
    DB_NAME(database_id) AS DatabaseName,
    name AS FileName,
    size * 8 / 1024 AS SizeMB,
    CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) * 8 / 1024 AS UsedMB,
    CAST(CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) * 100.0 / size AS DECIMAL(5,2)) AS PercentUsed
FROM sys.master_files
WHERE database_id = DB_ID('tempdb')
ORDER BY file_id;
```

**Schedule:** Run daily via SQL Agent job, alert if >70% used

### Capacity Planning

- Monitor TempDB growth trends weekly
- Plan for 20-30% headroom above peak usage
- Review query patterns quarterly
- Coordinate with development on new features

## Escalation

**Escalate to Database Team if:**
- TempDB growth >90% and cannot identify cause
- Killing sessions doesn't free space
- Recurring issue (>3 times per week)
- Performance impact to production applications

**Escalate to Infrastructure Team if:**
- Disk space cannot be extended
- Storage performance issues suspected
- Need to add additional storage

## Post-Incident

### Documentation

1. Record incident details:
   - Time of occurrence
   - TempDB size at peak
   - Queries/sessions identified
   - Actions taken
   - Resolution time

2. Update runbook if new scenario encountered

3. Schedule post-mortem if production impact

### Follow-Up Actions

- [ ] Review TempDB configuration against best practices
- [ ] Implement monitoring if not already in place
- [ ] Work with dev team on query optimization
- [ ] Schedule capacity planning review
- [ ] Update disaster recovery procedures

## References

- [Microsoft: TempDB Best Practices](https://docs.microsoft.com/en-us/sql/relational-databases/databases/tempdb-database)
- [TempDB Configuration Guidelines](https://www.brentozar.com/archive/2016/01/tempdb-configuration-survey-results/)
- Internal Wiki: SQL Server Standards

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2024-01-15 | Platform SRE Team | Initial version |
| 2024-06-20 | Platform SRE Team | Added Azure disk expansion steps |
