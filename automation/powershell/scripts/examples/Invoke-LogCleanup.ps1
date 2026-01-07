<#
.SYNOPSIS
    Log Cleanup Tool - SQL Server, IIS, and Bitvise SSH log cleanup

.DESCRIPTION
    This PowerShell script automatically detects and cleans logs from:
    - SQL Server Error Logs (ERRORLOG.* and SQLAGENT.*)
    - IIS Web Server Logs (*.log files older than 30 days from all sites)
    - Bitvise SSH Server Logs (*.log files older than 90 days)
    
    The script auto-detects installation locations on C: drive, shows file sizes,
    and prompts for confirmation before deleting each log type.

.FEATURES
    - Auto-detection of SQL Server, IIS, and Bitvise installations
    - File size reporting in MB/GB format
    - Separate confirmation for each log type
    - Safe deletion with error handling
    - Progress tracking and space freed reporting

.REQUIREMENTS
    - PowerShell 3.0 or higher
    - Administrator privileges recommended
    - Windows Server with SQL Server, IIS, and/or Bitvise installed
#>

#region Configuration - Edit This Section
# Set to 1 to use the hardcoded server array below, 0 to use parameters
$UseServersArray = 0

# Hardcoded server list (only used if $UseServersArray = 1)
$ServersArray = @(
    "SERVER01",
    "SERVER02",
    "SERVER03",
    "SERVER04",
    "SERVER05"
)
#endregion

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
    [string[]]$ComputerName,
    
    [Parameter(Mandatory=$false)]
    [string]$ComputerListPath,
    
    [Parameter(Mandatory=$false)]
    [int]$SQLRetentionDays = 0,  # 0 = keep only current logs
    
    [Parameter(Mandatory=$false)]
    [int]$IISRetentionDays = 30,
    
    [Parameter(Mandatory=$false)]
    [int]$SSHRetentionDays = 90,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoConfirm = $false,
    
    [Parameter(Mandatory=$false)]
    [PSCredential]$Credential
)

# Get list of computers to process
$computers = @()

if ($UseServersArray -eq 1) {
    # Use hardcoded server array from configuration section
    $computers = $ServersArray
    Write-Host "Using hardcoded server array from script configuration" -ForegroundColor Cyan
    Write-Host "Loaded $($computers.Count) server(s)" -ForegroundColor Green
} elseif ($ComputerListPath) {
    if (Test-Path $ComputerListPath) {
        Write-Host "Loading server list from: $ComputerListPath" -ForegroundColor Cyan
        $computers = Get-Content $ComputerListPath | Where-Object { $_ -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
        Write-Host "Loaded $($computers.Count) server(s)" -ForegroundColor Green
    } else {
        Write-Host "Server list file not found: $ComputerListPath" -ForegroundColor Red
        exit 1
    }
} elseif ($ComputerName) {
    $computers = $ComputerName
} else {
    # Default to localhost if no servers specified
    $computers = @("localhost")
    Write-Host "No servers specified, running on localhost" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Multi-Service Log Cleanup Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Servers to process: $($computers.Count)" -ForegroundColor Yellow
Write-Host "Retention Periods:" -ForegroundColor Yellow
Write-Host "  SQL Server: $(if($SQLRetentionDays -eq 0){'Current logs only'}else{"$SQLRetentionDays days"})" -ForegroundColor Gray
Write-Host "  IIS: $IISRetentionDays days" -ForegroundColor Gray
Write-Host "  SSH Server: $SSHRetentionDays days" -ForegroundColor Gray
Write-Host ""

# Script block to execute on each remote server
$scriptBlock = {
    param($SQLRetentionDays, $IISRetentionDays, $SSHRetentionDays, $AutoConfirm)
    
    # Function to format file size
function Format-FileSize {
    param([long]$Size)
    if ($Size -ge 1GB) { return "{0:N2} GB" -f ($Size / 1GB) }
    elseif ($Size -ge 1MB) { return "{0:N2} MB" -f ($Size / 1MB) }
    else { return "{0:N2} KB" -f ($Size / 1KB) }
}

# Function to clean logs with confirmation
function Cleanup-LogType {
    param(
        [string]$LogType,
        [array]$LogFiles
    )
    
    if ($LogFiles.Count -eq 0) {
        Write-Host "No old $LogType log files found to delete." -ForegroundColor Green
        return
    }
    
    Write-Host "`n=== $LogType Log Files ===" -ForegroundColor Cyan
    
    # Calculate total size and display files
    $totalSize = ($LogFiles | Measure-Object Length -Sum).Sum
    Write-Host "Files to delete:"
    foreach ($file in $LogFiles) {
        $age = ((Get-Date) - $file.LastWriteTime).Days
        Write-Host "  $($file.Name) - $(Format-FileSize $file.Length) ($age days old)" -ForegroundColor Gray
    }
    
    Write-Host "`nTotal: $($LogFiles.Count) files, $(Format-FileSize $totalSize)" -ForegroundColor Yellow
    
    # Confirm deletion
    $confirmation = Read-Host "`nDelete these $LogType log files? (Y/N)"
    if ($confirmation -eq "Y" -or $confirmation -eq "y") {
        $deleted = 0
        $freedSpace = 0
        
        foreach ($file in $LogFiles) {
            try {
                $size = $file.Length
                Remove-Item $file.FullName -Force
                Write-Host "Deleted: $($file.Name)" -ForegroundColor Green
                $deleted++
                $freedSpace += $size
            } catch {
                Write-Host "Failed: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        Write-Host "Completed: $deleted files deleted, $(Format-FileSize $freedSpace) freed" -ForegroundColor Green
    } else {
        Write-Host "$LogType log cleanup skipped." -ForegroundColor Yellow
    }
}

Write-Host "Log Cleanup Tool - SQL Server, IIS, and Bitvise" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# 1. DETECT AND CLEAN SQL SERVER LOGS
Write-Host "`n1. Detecting SQL Server installations..." -ForegroundColor Yellow

$sqlLogFiles = @()
$sqlSearchPaths = @(
    "C:\Program Files\Microsoft SQL Server\MSSQL*\MSSQL\Log",
    "C:\Program Files (x86)\Microsoft SQL Server\MSSQL*\MSSQL\Log"
)

foreach ($path in $sqlSearchPaths) {
    $basePath = Split-Path $path -Parent
    if (Test-Path (Split-Path $basePath -Parent)) {
        $found = Get-ChildItem -Path (Split-Path $basePath -Parent) -Directory | Where-Object { $_.Name -like "MSSQL*" }
        foreach ($dir in $found) {
            $logPath = Join-Path $dir.FullName "MSSQL\Log"
            if (Test-Path $logPath) {
                Write-Host "Found SQL Server: $($dir.Name) at $logPath" -ForegroundColor Green
                
                # Get old SQL log files (exclude current ERRORLOG and SQLAGENT.OUT)
                $oldLogs = Get-ChildItem -Path $logPath -File | Where-Object { 
                    ($_.Name -like "ERRORLOG.*") -or 
                    ($_.Name -like "SQLAGENT.*" -and $_.Name -ne "SQLAGENT.OUT")
                }
                $sqlLogFiles += $oldLogs
            }
        }
    }
}

if ($sqlLogFiles.Count -eq 0) {
    Write-Host "No SQL Server installations found." -ForegroundColor Red
}

# 2. DETECT AND CLEAN IIS LOGS
Write-Host "`n2. Detecting IIS installations..." -ForegroundColor Yellow

$iisLogFiles = @()
$iisLogBasePath = "C:\inetpub\logs\LogFiles"

if (Test-Path $iisLogBasePath) {
    $iisSites = Get-ChildItem -Path $iisLogBasePath -Directory | Where-Object { $_.Name -like "W3SVC*" }
    
    if ($iisSites.Count -gt 0) {
        foreach ($site in $iisSites) {
            Write-Host "Found IIS Site: $($site.Name) at $($site.FullName)" -ForegroundColor Green
            
            # Show total files in directory
            $allIISLogs = Get-ChildItem -Path $site.FullName -Filter "*.log" -File
            Write-Host "  Total log files in site: $($allIISLogs.Count)" -ForegroundColor Gray
            
            # Get IIS log files older than 30 days
            $cutoffDate = (Get-Date).AddDays(-30)
            $oldLogs = $allIISLogs | Where-Object { $_.LastWriteTime -lt $cutoffDate }
            Write-Host "  Log files older than 30 days: $($oldLogs.Count)" -ForegroundColor Gray
            $iisLogFiles += $oldLogs
        }
    } else {
        Write-Host "No IIS sites found." -ForegroundColor Red
    }
} else {
    Write-Host "IIS not found at $iisLogBasePath" -ForegroundColor Red
}

# 3. DETECT AND CLEAN BITVISE LOGS
Write-Host "`n3. Detecting Bitvise SSH Server..." -ForegroundColor Yellow

$bitviseLogFiles = @()
$bitviseLogPaths = @(
    "C:\Program Files\Bitvise SSH Server\Logs",
    "C:\Program Files (x86)\Bitvise SSH Server\Logs"
)

$bitviseFound = $false
foreach ($path in $bitviseLogPaths) {
    Write-Host "  Checking: $path" -ForegroundColor Gray
    if (Test-Path $path) {
        Write-Host "Found Bitvise SSH Server at $path" -ForegroundColor Green
        $bitviseFound = $true
        
        # Show all log files first
        $allBitviseFiles = Get-ChildItem -Path $path -Filter "*.log" -File -ErrorAction SilentlyContinue
        Write-Host "  Total log files found: $($allBitviseFiles.Count)" -ForegroundColor Gray
        
        if ($allBitviseFiles.Count -gt 0) {
            Write-Host "  Log files in directory:" -ForegroundColor Gray
            foreach ($logFile in $allBitviseFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 10) {
                $age = ((Get-Date) - $logFile.LastWriteTime).Days
                Write-Host "    $($logFile.Name) - $(Format-FileSize $logFile.Length) ($age days old)" -ForegroundColor DarkGray
            }
            if ($allBitviseFiles.Count -gt 10) {
                Write-Host "    ... and $($allBitviseFiles.Count - 10) more files" -ForegroundColor DarkGray
            }
        }
        
        # Get Bitvise log files older than 90 days (changed from 12 months to be more practical)
        $cutoffDate = (Get-Date).AddDays(-90)
        $oldLogs = $allBitviseFiles | Where-Object { $_.LastWriteTime -lt $cutoffDate }
        Write-Host "  Log files older than 90 days: $($oldLogs.Count)" -ForegroundColor Gray
        $bitviseLogFiles += $oldLogs
        break
    }
}

if (-not $bitviseFound) {
    Write-Host "Bitvise SSH Server not found in standard locations." -ForegroundColor Red
    
    # Offer manual path input for Bitvise
    $manualPath = Read-Host "Enter Bitvise log directory path manually (or press Enter to skip)"
    if ($manualPath -and (Test-Path $manualPath)) {
        Write-Host "Using manual path: $manualPath" -ForegroundColor Green
        $allBitviseFiles = Get-ChildItem -Path $manualPath -Filter "*.log" -File -ErrorAction SilentlyContinue
        Write-Host "  Total log files found: $($allBitviseFiles.Count)" -ForegroundColor Gray
        
        if ($allBitviseFiles.Count -gt 0) {
            $cutoffDate = (Get-Date).AddDays(-90)
            $oldLogs = $allBitviseFiles | Where-Object { $_.LastWriteTime -lt $cutoffDate }
            Write-Host "  Log files older than 90 days: $($oldLogs.Count)" -ForegroundColor Gray
            $bitviseLogFiles += $oldLogs
        }
    }
}

# PROCESS EACH LOG TYPE
Write-Host "`n" + "="*50 -ForegroundColor Magenta
Write-Host "LOG CLEANUP SUMMARY" -ForegroundColor Magenta
Write-Host "="*50 -ForegroundColor Magenta

# Clean SQL Server logs
if ($sqlLogFiles.Count -gt 0) {
    Cleanup-LogType -LogType "SQL Server" -LogFiles $sqlLogFiles
} else {
    Write-Host "`nNo SQL Server log files found to delete." -ForegroundColor Green
}

# Clean IIS logs
if ($iisLogFiles.Count -gt 0) {
    Cleanup-LogType -LogType "IIS" -LogFiles $iisLogFiles
} else {
    Write-Host "`nNo IIS log files found to delete." -ForegroundColor Green
}

# Clean Bitvise logs
if ($bitviseLogFiles.Count -gt 0) {
    Cleanup-LogType -LogType "Bitvise SSH" -LogFiles $bitviseLogFiles
} else {
    Write-Host "`nNo Bitvise SSH log files found to delete." -ForegroundColor Green
}

    # Return results
    return [PSCustomObject]@{
        ServerName = $env:COMPUTERNAME
        SQLFilesFound = $sqlLogFiles.Count
        IISFilesFound = $iisLogFiles.Count
        SSHFilesFound = $bitviseLogFiles.Count
        TotalFilesFound = $sqlLogFiles.Count + $iisLogFiles.Count + $bitviseLogFiles.Count
    }
}

# Execute cleanup on each server
$allResults = @()
$successCount = 0
$failCount = 0

foreach ($computer in $computers) {
    Write-Host "`nProcessing: $computer" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
    
    try {
        if ($computer -eq "localhost" -or $computer -eq $env:COMPUTERNAME) {
            # Run locally without Invoke-Command
            $result = & $scriptBlock -SQLRetentionDays $SQLRetentionDays -IISRetentionDays $IISRetentionDays -SSHRetentionDays $SSHRetentionDays -AutoConfirm $AutoConfirm
        } else {
            # Run remotely via Invoke-Command
            $invokeParams = @{
                ComputerName = $computer
                ScriptBlock  = $scriptBlock
                ArgumentList = $SQLRetentionDays, $IISRetentionDays, $SSHRetentionDays, $AutoConfirm
                ErrorAction  = 'Stop'
            }
            
            if ($Credential) {
                $invokeParams['Credential'] = $Credential
            }
            
            $result = Invoke-Command @invokeParams
        }
        
        if ($result) {
            $allResults += $result
            Write-Host "`n✓ Completed: $computer - Found $($result.TotalFilesFound) old log files" -ForegroundColor Green
            $successCount++
        }
        
    } catch {
        Write-Host "`n✗ Failed: $computer - $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
}

# Display final summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "CLEANUP SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Servers: $($computers.Count)" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if($failCount -gt 0){'Red'}else{'Green'})

if ($allResults.Count -gt 0) {
    Write-Host "`nResults by Server:" -ForegroundColor Yellow
    foreach ($result in $allResults) {
        Write-Host "  $($result.ServerName): SQL=$($result.SQLFilesFound), IIS=$($result.IISFilesFound), SSH=$($result.SSHFilesFound)" -ForegroundColor Gray
    }
}

Write-Host "`nLog cleanup process completed!" -ForegroundColor Cyan
