param(
    [string]$ServerListFile,
    [string]$TargetServers,
    [switch]$CleanSQL,
    [switch]$CleanIIS,
    [switch]$CleanBitvise,
    [switch]$CleanTempFolders,
    [switch]$CleanSFTP,
    [switch]$CleanSFTPArchive,
    [switch]$AutoConfirm,
    [int]$SQLLogRetentionDays = 0,
    [int]$IISLogRetentionDays = 30,
    [int]$BitviseLogRetentionDays = 90,
    [int]$TempFolderRetentionDays = 30,
    [int]$SFTPRetentionDays = 180,
    [int]$SFTPArchiveRetentionDays = 180
)

function Format-FileSize {
    param([long]$Size)
    if ($Size -ge 1GB) { return "{0:N2} GB" -f ($Size / 1GB) }
    elseif ($Size -ge 1MB) { return "{0:N2} MB" -f ($Size / 1MB) }
    else { return "{0:N2} KB" -f ($Size / 1KB) }
}

function Get-SafeConfirmation {
    param([string]$Message)
    
    if ($env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI -or $env:TF_BUILD -or $Host.Name -eq "ServerRemoteHost") {
        Write-Host "PIPELINE MODE: $Message - Proceeding automatically" -ForegroundColor Yellow
        return $true
    }
    
    try {
        $response = Read-Host $Message
        return ($response -eq "Y" -or $response -eq "y")
    } catch {
        Write-Host "Non-interactive environment detected - proceeding automatically" -ForegroundColor Yellow
        return $true
    }
}

Write-Host "=== Server Maintenance Pipeline Started ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date)"
Write-Host "Running User: $env:USERNAME"
Write-Host "Computer: $env:COMPUTERNAME"

if (-not ($CleanSQL -or $CleanIIS -or $CleanBitvise -or $CleanTempFolders -or $CleanSFTP -or $CleanSFTPArchive)) {
    Write-Host "No cleanup types selected." -ForegroundColor Red
    exit 1
}

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  SQL Server Cleanup: $CleanSQL"
Write-Host "  IIS Cleanup: $CleanIIS"
Write-Host "  Bitvise Cleanup: $CleanBitvise"
Write-Host "  Temp Folders Cleanup: $CleanTempFolders"
Write-Host "  SFTP Cleanup: $CleanSFTP"
Write-Host "  SFTP Archive Cleanup: $CleanSFTPArchive"
Write-Host "  Auto Confirm: $AutoConfirm"

$targetServerList = @()

if ($ServerListFile) {
    Write-Host "Loading servers from PowerShell file: $ServerListFile"
    if (Test-Path $ServerListFile) {
        $serverListContent = & $ServerListFile
        if ($serverListContent -is [array]) {
            $targetServerList = $serverListContent | Where-Object { $_ -and $_.Trim() -ne "" }
        } else {
            $targetServerList = Get-Content $ServerListFile | Where-Object { 
                $_.Trim() -ne "" -and -not $_.StartsWith("#") 
            }
        }
        
        Write-Host "Loaded $($targetServerList.Count) servers from PowerShell file"
        foreach ($server in $targetServerList) {
            Write-Host "  Server: $server"
        }
    } else {
        Write-Host "Server list file not found: $ServerListFile" -ForegroundColor Red
        exit 1
    }
} elseif ($TargetServers) {
    $targetServerList = $TargetServers -split "," | ForEach-Object { $_.Trim() }
    Write-Host "Target servers: $($targetServerList -join ', ')"
} else {
    $targetServerList = @("localhost")
    Write-Host "Using localhost"
}

if (-not $AutoConfirm) {
    $proceed = Get-SafeConfirmation "Proceed with server maintenance? (Y/N)"
    if (-not $proceed) {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        exit 0
    }
}

$totalDeleted = 0
$totalSpaceFreed = 0
$totalErrors = 0

# Remote script blocks for each cleanup type
$sqlCleanupScript = {
    param($RetentionDays)
    
    $results = @{
        InstancesFound = 0
        FilesDeleted = 0
        SpaceFreed = 0
        Errors = 0
        Details = @()
    }
    
    $sqlPaths = @(
        "C:\Program Files\Microsoft SQL Server",
        "C:\Program Files (x86)\Microsoft SQL Server"
    )
    
    foreach ($basePath in $sqlPaths) {
        if (Test-Path $basePath) {
            $instances = Get-ChildItem $basePath -Directory | Where-Object { 
                $_.Name -like "MSSQL*" -and $_.Name -notlike "*Tools*" 
            }
            
            foreach ($instance in $instances) {
                $logPath = Join-Path $instance.FullName "MSSQL\Log"
                if (Test-Path $logPath) {
                    $results.InstancesFound++
                    
                    $logs = Get-ChildItem $logPath -File | Where-Object { 
                        if ($RetentionDays -eq 0) {
                            $_.Name -like "ERRORLOG.*" -or ($_.Name -like "SQLAGENT.*" -and $_.Name -ne "SQLAGENT.OUT")
                        } else {
                            $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
                            (($_.Name -like "ERRORLOG*") -or ($_.Name -like "SQLAGENT*")) -and ($_.LastWriteTime -lt $cutoffDate)
                        }
                    }
                    
                    if ($logs.Count -gt 0) {
                        $instanceSize = ($logs | Measure-Object Length -Sum).Sum
                        $results.Details += "Instance: $($instance.Name) - $($logs.Count) files - $([Math]::Round($instanceSize/1MB, 2)) MB"
                        
                        foreach ($log in $logs) {
                            try {
                                $size = $log.Length
                                Remove-Item $log.FullName -Force
                                $results.FilesDeleted++
                                $results.SpaceFreed += $size
                            } catch {
                                $results.Errors++
                            }
                        }
                    }
                }
            }
        }
    }
    
    return $results
}

$iisCleanupScript = {
    param($RetentionDays)
    
    $results = @{
        SitesFound = 0
        FilesDeleted = 0
        SpaceFreed = 0
        Errors = 0
        Details = @()
    }
    
    $iisPath = "C:\inetpub\logs\LogFiles"
    
    if (Test-Path $iisPath) {
        $sites = Get-ChildItem $iisPath -Directory | Where-Object { $_.Name -like "W3SVC*" }
        
        foreach ($site in $sites) {
            $results.SitesFound++
            $cutoff = (Get-Date).AddDays(-$RetentionDays)
            $oldLogs = Get-ChildItem $site.FullName -Filter "*.log" -File | Where-Object { $_.LastWriteTime -lt $cutoff }
            
            if ($oldLogs.Count -gt 0) {
                $siteSize = ($oldLogs | Measure-Object Length -Sum).Sum
                $results.Details += "Site: $($site.Name) - $($oldLogs.Count) files - $([Math]::Round($siteSize/1MB, 2)) MB"
                
                try {
                    $oldLogs | Remove-Item -Force
                    $results.FilesDeleted += $oldLogs.Count
                    $results.SpaceFreed += $siteSize
                } catch {
                    foreach ($log in $oldLogs) {
                        try {
                            $size = $log.Length
                            Remove-Item $log.FullName -Force
                            $results.FilesDeleted++
                            $results.SpaceFreed += $size
                        } catch {
                            $results.Errors++
                        }
                    }
                }
            }
        }
    }
    
    return $results
}

$bitviseCleanupScript = {
    param($RetentionDays)
    
    $results = @{
        InstallFound = $false
        FilesDeleted = 0
        SpaceFreed = 0
        Errors = 0
        Details = @()
    }
    
    $bitvisePaths = @(
        "C:\Program Files\Bitvise SSH Server\Logs",
        "C:\Program Files (x86)\Bitvise SSH Server\Logs"
    )
    
    foreach ($path in $bitvisePaths) {
        if (Test-Path $path) {
            $results.InstallFound = $true
            $cutoff = (Get-Date).AddDays(-$RetentionDays)
            $oldLogs = Get-ChildItem $path -Filter "*.log" -File | Where-Object { $_.LastWriteTime -lt $cutoff }
            
            if ($oldLogs.Count -gt 0) {
                $totalSize = ($oldLogs | Measure-Object Length -Sum).Sum
                $results.Details += "Path: $path - $($oldLogs.Count) files - $([Math]::Round($totalSize/1MB, 2)) MB"
                
                foreach ($log in $oldLogs) {
                    try {
                        $size = $log.Length
                        Remove-Item $log.FullName -Force
                        $results.FilesDeleted++
                        $results.SpaceFreed += $size
                    } catch {
                        $results.Errors++
                    }
                }
            }
            break
        }
    }
    
    return $results
}

$tempCleanupScript = {
    param($RetentionDays)
    
    $results = @{
        FoldersProcessed = 0
        FilesDeleted = 0
        SpaceFreed = 0
        Errors = 0
        Details = @()
    }
    
    $tempPaths = @(
        "C:\Temp",
        "C:\Windows\Temp"
    )
    
    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    
    foreach ($tempPath in $tempPaths) {
        if (Test-Path $tempPath) {
            $results.FoldersProcessed++
            $results.Details += "Processing: $tempPath"
            
            try {
                $oldFiles = Get-ChildItem $tempPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object { 
                    $_.LastWriteTime -lt $cutoff -and
                    $_.Name -notlike "*.tmp" -and
                    $_.Name -notlike "*.temp" -and
                    $_.Extension -ne ".lock"
                }
                
                if ($oldFiles.Count -gt 0) {
                    $folderSize = ($oldFiles | Measure-Object Length -Sum).Sum
                    $results.Details += "  Found $($oldFiles.Count) files - $([Math]::Round($folderSize/1MB, 2)) MB"
                    
                    foreach ($file in $oldFiles) {
                        try {
                            $size = $file.Length
                            Remove-Item $file.FullName -Force -ErrorAction Stop
                            $results.FilesDeleted++
                            $results.SpaceFreed += $size
                        } catch {
                            $results.Errors++
                        }
                    }
                } else {
                    $results.Details += "  No files older than $RetentionDays days found"
                }
                
            } catch {
                $results.Errors++
                $results.Details += "  ERROR: Failed to process $tempPath - $($_.Exception.Message)"
            }
        } else {
            $results.Details += "  Folder not found: $tempPath"
        }
    }
    
    return $results
}

$sftpCleanupScript = {
    param($SFTPRetentionDays, $SFTPArchiveRetentionDays, $CleanSFTP, $CleanSFTPArchive)
    
    $results = @{
        FilesDeleted = 0
        SpaceFreed = 0
        Errors = 0
        Details = @()
        ArchivesDeleted = 0
        ArchiveSpaceFreed = 0
    }
    
    $foldersToClean = @()
    if ($CleanSFTP) { $foldersToClean += "F:\SFTP" }
    if ($CleanSFTPArchive) { $foldersToClean += "F:\SFTPArchive" }
    
    $regularCutoffDate = (Get-Date).AddDays(-$SFTPRetentionDays)
    $archiveCutoffDate = (Get-Date).AddDays(-$SFTPArchiveRetentionDays)
    
    foreach ($folder in $foldersToClean) {
        if (Test-Path $folder) {
            $results.Details += "Processing folder: $folder"
            
            try {
                $oldFiles = Get-ChildItem -Path $folder -Recurse -File | Where-Object {
                    $_.LastWriteTime -lt $regularCutoffDate -and $_.Name -ne "Archive"
                }
                
                if ($oldFiles.Count -gt 0) {
                    $folderSize = ($oldFiles | Measure-Object Length -Sum).Sum
                    $results.Details += "  Found $($oldFiles.Count) regular files - $([Math]::Round($folderSize/1MB, 2)) MB"
                    
                    foreach ($file in $oldFiles) {
                        try {
                            $size = $file.Length
                            Remove-Item $file.FullName -Force
                            $results.FilesDeleted++
                            $results.SpaceFreed += $size
                        } catch {
                            $results.Errors++
                        }
                    }
                }
                
                $oldArchives = Get-ChildItem -Path $folder -Filter "Archive" -File -Recurse | Where-Object {
                    $_.LastWriteTime -lt $archiveCutoffDate
                }
                
                if ($oldArchives.Count -gt 0) {
                    $archiveSize = ($oldArchives | Measure-Object Length -Sum).Sum
                    $results.Details += "  Found $($oldArchives.Count) archive files - $([Math]::Round($archiveSize/1MB, 2)) MB"
                    
                    foreach ($archive in $oldArchives) {
                        try {
                            $size = $archive.Length
                            Remove-Item $archive.FullName -Force
                            $results.ArchivesDeleted++
                            $results.ArchiveSpaceFreed += $size
                        } catch {
                            $results.Errors++
                        }
                    }
                }
                
            } catch {
                $results.Errors++
                $results.Details += "  ERROR: Failed to process folder $folder - $($_.Exception.Message)"
            }
        } else {
            $results.Details += "  Folder not found: $folder"
        }
    }
    
    return $results
}

foreach ($server in $targetServerList) {
    Write-Host "`n=== Processing Server: $server ===" -ForegroundColor Cyan
    
    if ($server -ne "localhost" -and $server -ne $env:COMPUTERNAME) {
        Write-Host "Testing connectivity to $server..."
        $ping = Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue
        if (-not $ping) {
            Write-Host "Cannot reach $server" -ForegroundColor Red
            continue
        }
        Write-Host "Server $server is reachable" -ForegroundColor Green
    }
    
    $useRemote = ($server -ne "localhost" -and $server -ne $env:COMPUTERNAME)
    
    if ($CleanSQL) {
        Write-Host "`nProcessing SQL Server logs on $server..." -ForegroundColor Yellow
        
        try {
            if ($useRemote) {
                $sqlResult = Invoke-Command -ComputerName $server -ScriptBlock $sqlCleanupScript -ArgumentList $SQLLogRetentionDays -ErrorAction Stop
            } else {
                $sqlResult = & $sqlCleanupScript -RetentionDays $SQLLogRetentionDays
            }
            
            Write-Host "SQL Server Results:"
            Write-Host "  Instances found: $($sqlResult.InstancesFound)"
            Write-Host "  Files deleted: $($sqlResult.FilesDeleted)"
            Write-Host "  Space freed: $(Format-FileSize $sqlResult.SpaceFreed)"
            Write-Host "  Errors: $($sqlResult.Errors)"
            
            foreach ($detail in $sqlResult.Details) {
                Write-Host "  $detail" -ForegroundColor Gray
            }
            
            $totalDeleted += $sqlResult.FilesDeleted
            $totalSpaceFreed += $sqlResult.SpaceFreed
            $totalErrors += $sqlResult.Errors
            
        } catch {
            Write-Host "Failed to execute SQL cleanup on $server`: $($_.Exception.Message)" -ForegroundColor Red
            $totalErrors++
        }
    }
    
    if ($CleanIIS) {
        Write-Host "`nProcessing IIS logs on $server..." -ForegroundColor Yellow
        
        try {
            if ($useRemote) {
                $iisResult = Invoke-Command -ComputerName $server -ScriptBlock $iisCleanupScript -ArgumentList $IISLogRetentionDays -ErrorAction Stop
            } else {
                $iisResult = & $iisCleanupScript -RetentionDays $IISLogRetentionDays
            }
            
            Write-Host "IIS Results:"
            Write-Host "  Sites found: $($iisResult.SitesFound)"
            Write-Host "  Files deleted: $($iisResult.FilesDeleted)"
            Write-Host "  Space freed: $(Format-FileSize $iisResult.SpaceFreed)"
            Write-Host "  Errors: $($iisResult.Errors)"
            
            foreach ($detail in $iisResult.Details) {
                Write-Host "  $detail" -ForegroundColor Gray
            }
            
            $totalDeleted += $iisResult.FilesDeleted
            $totalSpaceFreed += $iisResult.SpaceFreed
            $totalErrors += $iisResult.Errors
            
        } catch {
            Write-Host "Failed to execute IIS cleanup on $server`: $($_.Exception.Message)" -ForegroundColor Red
            $totalErrors++
        }
    }
    
    if ($CleanBitvise) {
        Write-Host "`nProcessing Bitvise logs on $server..." -ForegroundColor Yellow
        
        try {
            if ($useRemote) {
                $bitviseResult = Invoke-Command -ComputerName $server -ScriptBlock $bitviseCleanupScript -ArgumentList $BitviseLogRetentionDays -ErrorAction Stop
            } else {
                $bitviseResult = & $bitviseCleanupScript -RetentionDays $BitviseLogRetentionDays
            }
            
            Write-Host "Bitvise Results:"
            Write-Host "  Installation found: $($bitviseResult.InstallFound)"
            Write-Host "  Files deleted: $($bitviseResult.FilesDeleted)"
            Write-Host "  Space freed: $(Format-FileSize $bitviseResult.SpaceFreed)"
            Write-Host "  Errors: $($bitviseResult.Errors)"
            
            foreach ($detail in $bitviseResult.Details) {
                Write-Host "  $detail" -ForegroundColor Gray
            }
            
            $totalDeleted += $bitviseResult.FilesDeleted
            $totalSpaceFreed += $bitviseResult.SpaceFreed
            $totalErrors += $bitviseResult.Errors
            
        } catch {
            Write-Host "Failed to execute Bitvise cleanup on $server`: $($_.Exception.Message)" -ForegroundColor Red
            $totalErrors++
        }
    }
    
    if ($CleanTempFolders) {
        Write-Host "`nProcessing temp folders on $server..." -ForegroundColor Yellow
        
        try {
            if ($useRemote) {
                $tempResult = Invoke-Command -ComputerName $server -ScriptBlock $tempCleanupScript -ArgumentList $TempFolderRetentionDays -ErrorAction Stop
            } else {
                $tempResult = & $tempCleanupScript -RetentionDays $TempFolderRetentionDays
            }
            
            Write-Host "Temp Folders Results:"
            Write-Host "  Folders processed: $($tempResult.FoldersProcessed)"
            Write-Host "  Files deleted: $($tempResult.FilesDeleted)"
            Write-Host "  Space freed: $(Format-FileSize $tempResult.SpaceFreed)"
            Write-Host "  Errors: $($tempResult.Errors)"
            
            foreach ($detail in $tempResult.Details) {
                Write-Host "  $detail" -ForegroundColor Gray
            }
            
            $totalDeleted += $tempResult.FilesDeleted
            $totalSpaceFreed += $tempResult.SpaceFreed
            $totalErrors += $tempResult.Errors
            
        } catch {
            Write-Host "Failed to execute temp folder cleanup on $server`: $($_.Exception.Message)" -ForegroundColor Red
            $totalErrors++
        }
    }
    
    if ($CleanSFTP -or $CleanSFTPArchive) {
        Write-Host "`nProcessing SFTP folders on $server..." -ForegroundColor Yellow
        
        try {
            if ($useRemote) {
                $sftpResult = Invoke-Command -ComputerName $server -ScriptBlock $sftpCleanupScript -ArgumentList $SFTPRetentionDays, $SFTPArchiveRetentionDays, $CleanSFTP, $CleanSFTPArchive -ErrorAction Stop
            } else {
                $sftpResult = & $sftpCleanupScript -SFTPRetentionDays $SFTPRetentionDays -SFTPArchiveRetentionDays $SFTPArchiveRetentionDays -CleanSFTP $CleanSFTP -CleanSFTPArchive $CleanSFTPArchive
            }
            
            Write-Host "SFTP Results:"
            Write-Host "  Regular files deleted: $($sftpResult.FilesDeleted)"
            Write-Host "  Regular space freed: $(Format-FileSize $sftpResult.SpaceFreed)"
            Write-Host "  Archive files deleted: $($sftpResult.ArchivesDeleted)"
            Write-Host "  Archive space freed: $(Format-FileSize $sftpResult.ArchiveSpaceFreed)"
            Write-Host "  Errors: $($sftpResult.Errors)"
            
            foreach ($detail in $sftpResult.Details) {
                Write-Host "  $detail" -ForegroundColor Gray
            }
            
            $totalDeleted += ($sftpResult.FilesDeleted + $sftpResult.ArchivesDeleted)
            $totalSpaceFreed += ($sftpResult.SpaceFreed + $sftpResult.ArchiveSpaceFreed)
            $totalErrors += $sftpResult.Errors
            
        } catch {
            Write-Host "Failed to execute SFTP cleanup on $server`: $($_.Exception.Message)" -ForegroundColor Red
            $totalErrors++
        }
    }
}

Write-Host "`n=== FINAL SUMMARY ===" -ForegroundColor Cyan
Write-Host "Execution completed at: $(Get-Date)"
Write-Host "Total files deleted: $totalDeleted"
Write-Host "Total space freed: $(Format-FileSize $totalSpaceFreed)"
Write-Host "Total errors: $totalErrors"

Write-Host "##vso[task.setvariable variable=ServerMaintenance.TotalFilesDeleted]$totalDeleted"
Write-Host "##vso[task.setvariable variable=ServerMaintenance.TotalSpaceFreed]$totalSpaceFreed"
Write-Host "##vso[task.setvariable variable=ServerMaintenance.TotalErrors]$totalErrors"
Write-Host "##vso[task.setvariable variable=ServerMaintenance.ServersSuccessful]$($targetServerList.Count)"
Write-Host "##vso[task.setvariable variable=ServerMaintenance.ServersFailed]0"

if ($totalErrors -gt 0) {
    Write-Host "Operation completed with $totalErrors errors" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "Operation completed successfully!" -ForegroundColor Green
    exit 0
}


