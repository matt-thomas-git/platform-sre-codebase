<#
.SYNOPSIS
    SQL Server Health Check Script - Comprehensive database health monitoring

.DESCRIPTION
    Performs comprehensive health checks on SQL Server instances including:
    - Database status and sizes
    - TempDB configuration
    - Backup status
    - Disk space
    - SQL Agent job status
    - Long-running queries
    - Blocking sessions
    
    Generates detailed reports with color-coded output and CSV export.

.PARAMETER ServerInstance
    SQL Server instance name(s). Accepts a single server or an array of servers.
    Default: localhost

.PARAMETER ServerList
    Path to a text file containing server names (one per line)

.PARAMETER ExportPath
    Path to export CSV results. Default: C:\temp\SQL_Health_<timestamp>.csv

.PARAMETER CheckBackups
    Include backup status check (last backup time for all databases)

.PARAMETER CheckJobs
    Include SQL Agent job status check

.PARAMETER CheckPerformance
    Include performance metrics (blocking, long-running queries)

.EXAMPLE
    .\Get-SqlHealth.ps1 -ServerInstance "SQLSERVER01"
    
    Runs basic health check on SQLSERVER01.

.EXAMPLE
    .\Get-SqlHealth.ps1 -ServerInstance @("SQLSERVER01","SQLSERVER02","SQLSERVER03") -CheckBackups
    
    Runs health check on multiple servers with backup status.

.EXAMPLE
    .\Get-SqlHealth.ps1 -ServerList "C:\servers.txt" -CheckBackups -CheckJobs
    
    Runs comprehensive health check on servers listed in file.

.EXAMPLE
    .\Get-SqlHealth.ps1 -ServerInstance "SQLSERVER01" -CheckPerformance
    
    Includes performance monitoring (blocking sessions, long queries).

.NOTES
    Author: Platform SRE Team
    Requires: SqlServer PowerShell module
    Permissions: VIEW SERVER STATE, VIEW ANY DATABASE
#>

#region Configuration - Edit This Section
# Set to 1 to use the hardcoded server array below, 0 to use parameters
$UseServersArray = 0

# Hardcoded SQL Server list (only used if $UseServersArray = 1)
$ServersArray = @(
    "SQLSERVER01",
    "SQLSERVER02",
    "SQLSERVER03",
    "SQLSERVER04",
    "SQLSERVER05"
)
#endregion

[CmdletBinding(DefaultParameterSetName='ServerInstance')]
param(
    [Parameter(Mandatory=$false, ParameterSetName='ServerInstance')]
    [string[]]$ServerInstance = @("localhost"),
    
    [Parameter(Mandatory=$true, ParameterSetName='ServerList')]
    [ValidateScript({Test-Path $_})]
    [string]$ServerList,
    
    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "C:\temp\SQL_Health_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    
    [Parameter(Mandatory=$false)]
    [switch]$CheckBackups,
    
    [Parameter(Mandatory=$false)]
    [switch]$CheckJobs,
    
    [Parameter(Mandatory=$false)]
    [switch]$CheckPerformance
)

# Install SqlServer module if needed
if (!(Get-Module -ListAvailable -Name SqlServer)) {
    Write-Host "Installing SqlServer module..." -ForegroundColor Yellow
    Install-Module -Name SqlServer -Force -AllowClobber -Scope CurrentUser
}
Import-Module SqlServer

# Build server list
$servers = @()
if ($UseServersArray -eq 1) {
    # Use hardcoded server array from configuration section
    $servers = $ServersArray
    Write-Host "Using hardcoded SQL Server array from script configuration" -ForegroundColor Cyan
    Write-Host "Loaded $($servers.Count) SQL Server(s)" -ForegroundColor Green
} elseif ($PSCmdlet.ParameterSetName -eq 'ServerList') {
    $servers = Get-Content $ServerList | Where-Object { $_ -and $_.Trim() -ne '' }
    Write-Host "Loaded $($servers.Count) servers from file: $ServerList" -ForegroundColor Cyan
} else {
    $servers = $ServerInstance
}

# Create export directory
$exportDir = Split-Path $ExportPath -Parent
if (!(Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
}

$allHealthResults = @()

# Loop through each server
foreach ($server in $servers) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "   SQL SERVER HEALTH CHECK" -ForegroundColor Cyan
    Write-Host "   Server: $server" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $healthResults = @()

# 1. SERVER INFO
Write-Host "1. Server Information" -ForegroundColor Yellow
$serverInfoQuery = @"
SELECT 
    @@SERVERNAME as ServerName,
    @@VERSION as SQLVersion,
    SERVERPROPERTY('ProductVersion') as ProductVersion,
    SERVERPROPERTY('ProductLevel') as ProductLevel,
    SERVERPROPERTY('Edition') as Edition,
    SERVERPROPERTY('IsClustered') as IsClustered
"@

try {
    $serverInfo = Invoke-Sqlcmd -ServerInstance $server -Query $serverInfoQuery -TrustServerCertificate
    Write-Host "  Server: $($serverInfo.ServerName)" -ForegroundColor Green
    Write-Host "  Edition: $($serverInfo.Edition)" -ForegroundColor Gray
    Write-Host "  Version: $($serverInfo.ProductVersion) $($serverInfo.ProductLevel)" -ForegroundColor Gray
    Write-Host "  Clustered: $($serverInfo.IsClustered)" -ForegroundColor Gray
} catch {
    Write-Host "  Failed to retrieve server info: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. DATABASE STATUS AND SIZES
Write-Host "`n2. Database Status and Sizes" -ForegroundColor Yellow
$dbStatusQuery = @"
SELECT 
    name as DatabaseName,
    state_desc as Status,
    recovery_model_desc as RecoveryModel,
    CAST(SUM(size) * 8.0 / 1024 as DECIMAL(10,2)) as SizeMB
FROM sys.databases d
LEFT JOIN sys.master_files mf ON d.database_id = mf.database_id
WHERE d.database_id > 4  -- Exclude system databases for size calc
GROUP BY name, state_desc, recovery_model_desc
ORDER BY SizeMB DESC
"@

try {
    $databases = Invoke-Sqlcmd -ServerInstance $server -Query $dbStatusQuery -TrustServerCertificate
    Write-Host "  Total User Databases: $($databases.Count)" -ForegroundColor Green
    
    foreach ($db in $databases) {
        $statusColor = if ($db.Status -eq "ONLINE") { "Green" } else { "Red" }
        Write-Host "  $($db.DatabaseName): $($db.Status) - $($db.SizeMB) MB ($($db.RecoveryModel))" -ForegroundColor $statusColor
        
        $healthResults += [PSCustomObject]@{
            Category = "Database"
            Item = $db.DatabaseName
            Status = $db.Status
            Details = "$($db.SizeMB) MB, $($db.RecoveryModel)"
            Severity = if ($db.Status -eq "ONLINE") { "OK" } else { "Critical" }
        }
    }
} catch {
    Write-Host "  Failed to retrieve database info: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. TEMPDB CONFIGURATION
Write-Host "`n3. TempDB Configuration" -ForegroundColor Yellow
$tempdbQuery = @"
SELECT 
    name as FileName,
    type_desc as FileType,
    physical_name as FilePath,
    CAST(size * 8.0 / 1024 as DECIMAL(10,2)) as CurrentSizeMB,
    CASE WHEN max_size = -1 THEN 'UNLIMITED' ELSE CAST(max_size * 8.0 / 1024 as VARCHAR(20)) END as MaxSize
FROM sys.master_files
WHERE database_id = DB_ID('tempdb')
ORDER BY type, file_id
"@

try {
    $tempdbFiles = Invoke-Sqlcmd -ServerInstance $server -Query $tempdbQuery -TrustServerCertificate
    Write-Host "  TempDB Files: $($tempdbFiles.Count)" -ForegroundColor Green
    
    foreach ($file in $tempdbFiles) {
        $maxSizeColor = if ($file.MaxSize -eq "UNLIMITED") { "Green" } else { "Yellow" }
        Write-Host "  $($file.FileName) ($($file.FileType)): $($file.CurrentSizeMB) MB, Max: $($file.MaxSize)" -ForegroundColor $maxSizeColor
    }
} catch {
    Write-Host "  Failed to retrieve TempDB info: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. DISK SPACE
Write-Host "`n4. Disk Space" -ForegroundColor Yellow
$diskSpaceQuery = @"
EXEC xp_fixeddrives
"@

try {
    $diskSpace = Invoke-Sqlcmd -ServerInstance $server -Query $diskSpaceQuery -TrustServerCertificate
    foreach ($disk in $diskSpace) {
        $freeSpaceGB = [math]::Round($disk.'MB free' / 1024, 2)
        $color = if ($freeSpaceGB -lt 10) { "Red" } elseif ($freeSpaceGB -lt 50) { "Yellow" } else { "Green" }
        Write-Host "  Drive $($disk.drive): $freeSpaceGB GB free" -ForegroundColor $color
        
        $healthResults += [PSCustomObject]@{
            Category = "DiskSpace"
            Item = "Drive $($disk.drive)"
            Status = "$freeSpaceGB GB free"
            Details = ""
            Severity = if ($freeSpaceGB -lt 10) { "Critical" } elseif ($freeSpaceGB -lt 50) { "Warning" } else { "OK" }
        }
    }
} catch {
    Write-Host "  Failed to retrieve disk space: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. BACKUP STATUS (if requested)
if ($CheckBackups) {
    Write-Host "`n5. Backup Status" -ForegroundColor Yellow
    $backupQuery = @"
SELECT 
    d.name as DatabaseName,
    MAX(b.backup_finish_date) as LastBackup,
    DATEDIFF(hour, MAX(b.backup_finish_date), GETDATE()) as HoursSinceBackup
FROM sys.databases d
LEFT JOIN msdb.dbo.backupset b ON d.name = b.database_name AND b.type = 'D'
WHERE d.database_id > 4
GROUP BY d.name
ORDER BY HoursSinceBackup DESC
"@

    try {
        $backups = Invoke-Sqlcmd -ServerInstance $server -Query $backupQuery -TrustServerCertificate
        foreach ($backup in $backups) {
            $hours = if ($backup.HoursSinceBackup) { $backup.HoursSinceBackup } else { 999 }
            $color = if ($hours -gt 48) { "Red" } elseif ($hours -gt 24) { "Yellow" } else { "Green" }
            $lastBackup = if ($backup.LastBackup) { $backup.LastBackup } else { "Never" }
            Write-Host "  $($backup.DatabaseName): Last backup $lastBackup ($hours hours ago)" -ForegroundColor $color
        }
    } catch {
        Write-Host "  Failed to retrieve backup info: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 6. SQL AGENT JOBS (if requested)
if ($CheckJobs) {
    Write-Host "`n6. SQL Agent Job Status" -ForegroundColor Yellow
    $jobsQuery = @"
SELECT 
    j.name as JobName,
    j.enabled as IsEnabled,
    CASE jh.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
    END as LastRunStatus,
    msdb.dbo.agent_datetime(jh.run_date, jh.run_time) as LastRunTime
FROM msdb.dbo.sysjobs j
LEFT JOIN (
    SELECT job_id, run_status, run_date, run_time,
           ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY run_date DESC, run_time DESC) as rn
    FROM msdb.dbo.sysjobhistory
    WHERE step_id = 0
) jh ON j.job_id = jh.job_id AND jh.rn = 1
WHERE j.enabled = 1
ORDER BY LastRunTime DESC
"@

    try {
        $jobs = Invoke-Sqlcmd -ServerInstance $server -Query $jobsQuery -TrustServerCertificate
        $failedJobs = $jobs | Where-Object { $_.LastRunStatus -eq 'Failed' }
        
        Write-Host "  Total Enabled Jobs: $($jobs.Count)" -ForegroundColor Green
        Write-Host "  Failed Jobs: $($failedJobs.Count)" -ForegroundColor $(if ($failedJobs.Count -gt 0) { "Red" } else { "Green" })
        
        if ($failedJobs.Count -gt 0) {
            foreach ($job in $failedJobs) {
                Write-Host "    FAILED: $($job.JobName) - Last run: $($job.LastRunTime)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "  Failed to retrieve job info: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 7. PERFORMANCE CHECKS (if requested)
if ($CheckPerformance) {
    Write-Host "`n7. Performance Monitoring" -ForegroundColor Yellow
    
    # Check for blocking
    $blockingQuery = @"
SELECT 
    blocking_session_id,
    session_id,
    wait_type,
    wait_time,
    wait_resource
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0
"@

    try {
        $blocking = Invoke-Sqlcmd -ServerInstance $server -Query $blockingQuery -TrustServerCertificate
        if ($blocking.Count -gt 0) {
            Write-Host "  WARNING: $($blocking.Count) blocked sessions detected!" -ForegroundColor Red
            foreach ($block in $blocking) {
                Write-Host "    Session $($block.session_id) blocked by $($block.blocking_session_id)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  No blocking detected" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Failed to check blocking: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Check for long-running queries
    $longQueryQuery = @"
SELECT TOP 5
    session_id,
    DATEDIFF(second, start_time, GETDATE()) as DurationSeconds,
    status,
    command,
    DB_NAME(database_id) as DatabaseName
FROM sys.dm_exec_requests
WHERE session_id > 50
ORDER BY start_time
"@

    try {
        $longQueries = Invoke-Sqlcmd -ServerInstance $server -Query $longQueryQuery -TrustServerCertificate
        $longRunning = $longQueries | Where-Object { $_.DurationSeconds -gt 300 }
        
        if ($longRunning.Count -gt 0) {
            Write-Host "  WARNING: $($longRunning.Count) long-running queries (>5 min)" -ForegroundColor Yellow
        } else {
            Write-Host "  No long-running queries detected" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Failed to check long queries: $($_.Exception.Message)" -ForegroundColor Red
    }
}

    # Add server name to results and append to all results
    foreach ($result in $healthResults) {
        $result | Add-Member -MemberType NoteProperty -Name "ServerName" -Value $server -Force
    }
    $allHealthResults += $healthResults
}

# Export all results
if ($allHealthResults.Count -gt 0) {
    $allHealthResults | Export-Csv -Path $ExportPath -NoTypeInformation
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "All results exported to: $ExportPath" -ForegroundColor Green
    Write-Host "Total servers checked: $($servers.Count)" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
}

Write-Host "`nHealth check completed for all servers!" -ForegroundColor Green
