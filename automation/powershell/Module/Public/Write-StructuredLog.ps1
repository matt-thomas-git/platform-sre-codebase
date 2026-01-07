function Write-StructuredLog {
    <#
    .SYNOPSIS
        Writes structured log entries in JSON format for centralized logging systems.
    
    .DESCRIPTION
        Creates structured log entries that can be ingested by log aggregation systems
        like Azure Log Analytics, Splunk, or ELK stack. Includes timestamp, severity,
        message, and custom properties.
    
    .PARAMETER Message
        The log message to write.
    
    .PARAMETER Severity
        Log severity level: Information, Warning, Error, Critical. Default is Information.
    
    .PARAMETER Properties
        Hashtable of additional properties to include in the log entry.
    
    .PARAMETER LogPath
        Optional file path to write logs. If not specified, writes to console only.
    
    .EXAMPLE
        Write-StructuredLog -Message "Server patching completed" -Severity Information -Properties @{
            ServerName = "SERVER01"
            PatchCount = 15
            Duration = "00:45:30"
        }
        
        Writes a structured log entry with custom properties.
    
    .EXAMPLE
        Write-StructuredLog -Message "Database connection failed" -Severity Error -Properties @{
            Database = "ProductionDB"
            ErrorCode = "08001"
        } -LogPath "C:\Logs\automation.log"
        
        Writes an error log entry to both console and file.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Information', 'Warning', 'Error', 'Critical')]
        [string]$Severity = 'Information',
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Properties = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$LogPath
    )
    
    # Create structured log entry
    $logEntry = [PSCustomObject]@{
        Timestamp  = (Get-Date).ToUniversalTime().ToString('o')
        Severity   = $Severity
        Message    = $Message
        MachineName = $env:COMPUTERNAME
        User       = $env:USERNAME
        ProcessId  = $PID
        Properties = $Properties
    }
    
    # Convert to JSON
    $jsonLog = $logEntry | ConvertTo-Json -Compress
    
    # Write to console with color coding
    switch ($Severity) {
        'Information' { Write-Host $jsonLog -ForegroundColor Cyan }
        'Warning'     { Write-Host $jsonLog -ForegroundColor Yellow }
        'Error'       { Write-Host $jsonLog -ForegroundColor Red }
        'Critical'    { Write-Host $jsonLog -ForegroundColor Magenta }
    }
    
    # Write to file if path specified
    if ($LogPath) {
        try {
            # Ensure directory exists
            $logDir = Split-Path -Path $LogPath -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            
            # Append to log file
            Add-Content -Path $LogPath -Value $jsonLog -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }
    
    # Return the log entry object
    return $logEntry
}
