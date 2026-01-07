<#
.SYNOPSIS
    Server Administrator and RDP User Audit Tool

.DESCRIPTION
    This script audits local administrator and Remote Desktop Users group membership
    across multiple Windows servers. It provides:
    1. List of all local administrators on each server
    2. List of users with Remote Desktop access
    3. Comparison against expected/baseline configurations
    4. Export to CSV for compliance reporting
    
    Useful for security audits, compliance checks, and access reviews.

.PARAMETER ComputerName
    Array of computer names to audit. Can be a single server or multiple servers.

.PARAMETER ComputerListPath
    Path to a text file containing server names (one per line).

.PARAMETER ExportPath
    Path to export audit results CSV. Default: C:\temp\ServerAdminAudit_<timestamp>.csv

.PARAMETER IncludeBuiltIn
    Include built-in accounts (Administrator, Domain Admins) in the report.
    Default: $false (excludes built-in accounts for cleaner reporting)

.PARAMETER Credential
    PSCredential object for remote authentication. If not provided, uses current user context.

.EXAMPLE
    .\Get-ServerAdminAudit.ps1 -ComputerName "SERVER01","SERVER02","SERVER03"
    
    Audit three servers and export results.

.EXAMPLE
    .\Get-ServerAdminAudit.ps1 -ComputerListPath "C:\servers.txt"
    
    Audit all servers listed in the text file.

.EXAMPLE
    .\Get-ServerAdminAudit.ps1 -ComputerName "SERVER01" -IncludeBuiltIn
    
    Audit a single server including built-in accounts.

.EXAMPLE
    $cred = Get-Credential
    .\Get-ServerAdminAudit.ps1 -ComputerName "SERVER01" -Credential $cred
    
    Audit using alternate credentials.

.NOTES
    Author: Platform SRE Team
    Requires: PowerShell Remoting enabled on target servers
    Permissions: Local Administrator or equivalent on target servers
    
    For servers.txt format, use one server name per line:
    SERVER01
    SERVER02
    SERVER03
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
    [string]$ExportPath = "C:\temp\ServerAdminAudit_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeBuiltIn = $false,
    
    [Parameter(Mandatory=$false)]
    [PSCredential]$Credential
)

# Create export directory if needed
$exportDir = Split-Path $ExportPath -Parent
if (!(Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
}

# Get list of computers to audit
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
    Write-Host "No servers specified. Use -ComputerName, -ComputerListPath parameter, or set `$UseServersArray = 1" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Server Administrator Audit Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Servers to audit: $($computers.Count)" -ForegroundColor Yellow
Write-Host "Include built-in accounts: $IncludeBuiltIn" -ForegroundColor Yellow
Write-Host ""

# Script block to execute remotely
$scriptBlock = {
    param($IncludeBuiltIn)
    
    $results = @()
    
    try {
        # Get members of the local Administrators group
        $adminGroup = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop
        
        foreach ($member in $adminGroup) {
            # Skip built-in accounts if requested
            if (-not $IncludeBuiltIn) {
                if ($member.Name -like "*\Administrator" -or 
                    $member.Name -like "*\Domain Admins" -or
                    $member.Name -eq "BUILTIN\Administrators") {
                    continue
                }
            }
            
            $results += [PSCustomObject]@{
                ServerName    = $env:COMPUTERNAME
                GroupType     = "Administrators"
                MemberName    = $member.Name
                MemberType    = $member.ObjectClass
                PrincipalSource = $member.PrincipalSource
                Status        = "Success"
                ErrorMessage  = ""
            }
        }
        
        # Get users allowed for Remote Desktop access
        try {
            $rdpGroup = Get-LocalGroupMember -Group "Remote Desktop Users" -ErrorAction Stop
            
            foreach ($member in $rdpGroup) {
                $results += [PSCustomObject]@{
                    ServerName    = $env:COMPUTERNAME
                    GroupType     = "Remote Desktop Users"
                    MemberName    = $member.Name
                    MemberType    = $member.ObjectClass
                    PrincipalSource = $member.PrincipalSource
                    Status        = "Success"
                    ErrorMessage  = ""
                }
            }
        } catch {
            # RDP group might be empty or not exist
            $results += [PSCustomObject]@{
                ServerName    = $env:COMPUTERNAME
                GroupType     = "Remote Desktop Users"
                MemberName    = "N/A"
                MemberType    = "N/A"
                PrincipalSource = "N/A"
                Status        = "Warning"
                ErrorMessage  = "No RDP users or group not accessible"
            }
        }
        
    } catch {
        # If any errors occur, return error result
        $results += [PSCustomObject]@{
            ServerName    = $env:COMPUTERNAME
            GroupType     = "Error"
            MemberName    = "N/A"
            MemberType    = "N/A"
            PrincipalSource = "N/A"
            Status        = "Failed"
            ErrorMessage  = $_.Exception.Message
        }
    }
    
    return $results
}

# Invoke the command remotely on each server
$allResults = @()
$successCount = 0
$failCount = 0

foreach ($computer in $computers) {
    Write-Host "Auditing: $computer" -ForegroundColor Cyan
    
    try {
        $invokeParams = @{
            ComputerName = $computer
            ScriptBlock  = $scriptBlock
            ArgumentList = $IncludeBuiltIn
            ErrorAction  = 'Stop'
        }
        
        if ($Credential) {
            $invokeParams['Credential'] = $Credential
        }
        
        $result = Invoke-Command @invokeParams
        
        if ($result) {
            $allResults += $result
            
            # Count unique members per group type
            $adminCount = ($result | Where-Object { $_.GroupType -eq "Administrators" }).Count
            $rdpCount = ($result | Where-Object { $_.GroupType -eq "Remote Desktop Users" }).Count
            
            Write-Host "  ✓ Success - Admins: $adminCount, RDP Users: $rdpCount" -ForegroundColor Green
            $successCount++
        }
        
    } catch {
        Write-Host "  ✗ Failed - $($_.Exception.Message)" -ForegroundColor Red
        
        $allResults += [PSCustomObject]@{
            ServerName      = $computer
            GroupType       = "Error"
            MemberName      = "N/A"
            MemberType      = "N/A"
            PrincipalSource = "N/A"
            Status          = "Failed"
            ErrorMessage    = $_.Exception.Message
        }
        
        $failCount++
    }
}

# Display summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "AUDIT SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Servers: $($computers.Count)" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if($failCount -gt 0){'Red'}else{'Green'})
Write-Host "Total Entries: $($allResults.Count)" -ForegroundColor White

# Group by server and display details
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "DETAILED RESULTS" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

$groupedResults = $allResults | Group-Object ServerName

foreach ($group in $groupedResults) {
    Write-Host "`n--- $($group.Name) ---" -ForegroundColor Yellow
    
    $admins = $group.Group | Where-Object { $_.GroupType -eq "Administrators" }
    if ($admins) {
        Write-Host "  Administrators:" -ForegroundColor Cyan
        foreach ($admin in $admins) {
            Write-Host "    - $($admin.MemberName) ($($admin.MemberType))" -ForegroundColor Gray
        }
    }
    
    $rdpUsers = $group.Group | Where-Object { $_.GroupType -eq "Remote Desktop Users" }
    if ($rdpUsers) {
        Write-Host "  Remote Desktop Users:" -ForegroundColor Cyan
        foreach ($rdp in $rdpUsers) {
            Write-Host "    - $($rdp.MemberName) ($($rdp.MemberType))" -ForegroundColor Gray
        }
    }
    
    $errorEntries = $group.Group | Where-Object { $_.Status -eq "Failed" }
    if ($errorEntries) {
        Write-Host "  Errors:" -ForegroundColor Red
        foreach ($errorEntry in $errorEntries) {
            Write-Host "    - $($errorEntry.ErrorMessage)" -ForegroundColor Red
        }
    }
}

# Export results to CSV
if ($allResults.Count -gt 0) {
    $allResults | Export-Csv -Path $ExportPath -NoTypeInformation
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Results exported to: $ExportPath" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
}

# Highlight any servers with failures
$failedServers = $allResults | Where-Object { $_.Status -eq "Failed" } | Select-Object -ExpandProperty ServerName -Unique
if ($failedServers) {
    Write-Host "`n⚠ WARNING: The following servers had errors:" -ForegroundColor Yellow
    foreach ($server in $failedServers) {
        Write-Host "  - $server" -ForegroundColor Red
    }
}

Write-Host "`nAudit completed!" -ForegroundColor Cyan
