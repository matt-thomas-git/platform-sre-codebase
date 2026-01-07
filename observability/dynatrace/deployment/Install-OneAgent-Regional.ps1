<#
.SYNOPSIS
    Automated Dynatrace OneAgent deployment across multiple network zones

.DESCRIPTION
    Deploys Dynatrace OneAgent to servers across different Azure regions using
    regional ActiveGates and network zones for optimal routing and monitoring.
    
    This script demonstrates:
    - Multi-region deployment automation
    - Network zone configuration
    - ActiveGate integration
    - Centralized logging and reporting

.PARAMETER MsiPath
    Path to the Dynatrace OneAgent MSI installer

.PARAMETER ConfigFile
    Optional JSON config file with network zones and server mappings

.EXAMPLE
    .\Install-OneAgent-Regional.ps1 -MsiPath "\\fileserver\software\Dynatrace-OneAgent.msi"

.NOTES
    Author: Platform SRE Team
    Requires: PowerShell Remoting enabled on target servers
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$MsiPath,
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile
)

# Default configuration - customize for your environment
$installConfig = @(
    @{ 
        NetworkZone = "azure.eastus2.prod"
        ActiveGate = "https://activegate-eus2.company.local:9999/communication"
        Servers = @("app-server-01.company.local", "app-server-02.company.local")
    },
    @{ 
        NetworkZone = "azure.westeurope.prod"
        ActiveGate = "https://activegate-weu.company.local:9999/communication"
        Servers = @("app-server-03.company.local", "app-server-04.company.local")
    },
    @{ 
        NetworkZone = "azure.southeastasia.prod"
        ActiveGate = "https://activegate-sea.company.local:9999/communication"
        Servers = @("app-server-05.company.local")
    }
)

# Load config from file if provided
if ($ConfigFile -and (Test-Path $ConfigFile)) {
    Write-Host "Loading configuration from: $ConfigFile" -ForegroundColor Cyan
    $installConfig = Get-Content $ConfigFile | ConvertFrom-Json
}

# Display configuration
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Dynatrace OneAgent Regional Deployment" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Configuration:" -ForegroundColor Yellow
$installConfig | ForEach-Object {
    Write-Host "  Network Zone: $($_.NetworkZone)" -ForegroundColor White
    Write-Host "  Active Gate:  $($_.ActiveGate)" -ForegroundColor Gray
    Write-Host "  Servers:      $($_.Servers -join ', ')" -ForegroundColor Gray
    Write-Host ""
}

# Confirm before proceeding
$confirmation = Read-Host "Proceed with installation? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Installation cancelled." -ForegroundColor Yellow
    exit 0
}

# Locate MSI installer
if (-not $MsiPath) {
    $defaultPath = "\\fileserver\software\Dynatrace"
    Write-Host "`nSearching for OneAgent installer in: $defaultPath" -ForegroundColor Cyan
    
    if (Test-Path $defaultPath) {
        $msiFiles = Get-ChildItem -Path $defaultPath -Filter "Dynatrace-OneAgent-Windows-*.msi" | 
                    Sort-Object LastWriteTime -Descending
        
        if ($msiFiles) {
            $MsiPath = $msiFiles[0].FullName
            Write-Host "Found: $MsiPath" -ForegroundColor Green
        }
    }
}

if (-not $MsiPath -or -not (Test-Path $MsiPath)) {
    Write-Host "ERROR: OneAgent installer not found. Please specify -MsiPath" -ForegroundColor Red
    exit 1
}

# Setup logging
$tempFolder = "C:\temp"
if (!(Test-Path $tempFolder)) { 
    New-Item -ItemType Directory -Path $tempFolder | Out-Null 
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$tempFolder\Dynatrace_Install_$timestamp.csv"
$detailedLog = "$tempFolder\Dynatrace_Install_$timestamp.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $detailedLog -Value $logEntry
    
    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARN"  { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        default { Write-Host $Message -ForegroundColor White }
    }
}

Write-Log "Starting Dynatrace OneAgent deployment" "INFO"
Write-Log "MSI Path: $MsiPath" "INFO"

# Install OneAgent on each server
$installResults = @()
$successCount = 0
$failCount = 0

foreach ($config in $installConfig) {
    $networkZone = $config.NetworkZone
    $activeGate = $config.ActiveGate
    
    Write-Log "`nProcessing Network Zone: $networkZone" "INFO"
    
    foreach ($server in $config.Servers) {
        Write-Log "Installing on: $server" "INFO"
        
        try {
            # Test connectivity first
            if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
                throw "Server unreachable"
            }
            
            # Build installation command
            $installArgs = @(
                "/i `"$MsiPath`""
                "/quiet"
                "/norestart"
                "PRECONFIGURED_PARAMETERS=`"--set-server=$activeGate --set-network-zone=$networkZone`""
            )
            
            $installCommand = $installArgs -join " "
            
            # Execute remote installation
            $result = Invoke-Command -ComputerName $server -ScriptBlock {
                param($msiPath, $args)
                
                # Copy MSI locally for faster installation
                $localMsi = "C:\temp\Dynatrace-OneAgent.msi"
                if (!(Test-Path "C:\temp")) { New-Item -ItemType Directory -Path "C:\temp" | Out-Null }
                Copy-Item -Path $msiPath -Destination $localMsi -Force
                
                # Install
                $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $args -NoNewWindow -Wait -PassThru
                
                # Cleanup
                Remove-Item -Path $localMsi -Force -ErrorAction SilentlyContinue
                
                return $process.ExitCode
            } -ArgumentList $MsiPath, $installCommand -ErrorAction Stop
            
            if ($result -eq 0) {
                Write-Log "  ✓ Successfully installed on $server" "SUCCESS"
                $installResults += [PSCustomObject]@{
                    Server = $server
                    NetworkZone = $networkZone
                    Status = "Success"
                    ExitCode = $result
                    Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                }
                $successCount++
            } else {
                throw "Installation returned exit code: $result"
            }
        }
        catch {
            Write-Log "  ✗ Failed to install on $server - $($_.Exception.Message)" "ERROR"
            $installResults += [PSCustomObject]@{
                Server = $server
                NetworkZone = $networkZone
                Status = "Failed"
                Error = $_.Exception.Message
                Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
            $failCount++
        }
        
        Start-Sleep -Seconds 2
    }
}

# Export results
$installResults | Export-Csv -Path $logFile -NoTypeInformation

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Servers:  $($successCount + $failCount)" -ForegroundColor White
Write-Host "Successful:     $successCount" -ForegroundColor Green
Write-Host "Failed:         $failCount" -ForegroundColor $(if($failCount -gt 0){"Red"}else{"Green"})
Write-Host "`nResults saved to:" -ForegroundColor Cyan
Write-Host "  CSV:  $logFile" -ForegroundColor Gray
Write-Host "  Log:  $detailedLog" -ForegroundColor Gray

if ($failCount -gt 0) {
    Write-Host "`nFailed Servers:" -ForegroundColor Red
    $installResults | Where-Object { $_.Status -eq "Failed" } | ForEach-Object {
        Write-Host "  - $($_.Server): $($_.Error)" -ForegroundColor Red
    }
}

Write-Log "`nDeployment completed. Success: $successCount, Failed: $failCount" "INFO"

exit $(if($failCount -eq 0){0}else{1})
