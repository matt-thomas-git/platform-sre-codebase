<#
.SYNOPSIS
    Creates Dynatrace network zones via API for multi-region monitoring

.DESCRIPTION
    Automates the creation of network zones in Dynatrace to organize monitoring
    by geographic region or network segment. Network zones ensure OneAgents
    communicate with the nearest ActiveGate for optimal performance.

.PARAMETER ApiToken
    Dynatrace API token with networkZones.write permission

.PARAMETER TenantUrl
    Dynatrace tenant URL (e.g., https://abc12345.live.dynatrace.com)

.PARAMETER ConfigFile
    Optional JSON file containing network zone definitions

.EXAMPLE
    .\Create-NetworkZones.ps1 -ApiToken "dt0c01.ABC123..." -TenantUrl "https://abc12345.live.dynatrace.com"

.NOTES
    Author: Platform SRE Team
    API Documentation: https://www.dynatrace.com/support/help/dynatrace-api/environment-api/network-zones
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ApiToken,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile
)

# Remove trailing slash from tenant URL
$TenantUrl = $TenantUrl.TrimEnd('/')

# Setup headers
$headers = @{
    "Authorization" = "Api-Token $ApiToken"
    "Content-Type"  = "application/json"
}

# Default network zones - customize for your environment
$networkZones = @(
    @{ 
        name = "azure.eastus2.prod"
        description = "Production Network Zone - Azure East US 2"
    },
    @{ 
        name = "azure.westeurope.prod"
        description = "Production Network Zone - Azure West Europe"
    },
    @{ 
        name = "azure.southeastasia.prod"
        description = "Production Network Zone - Azure Southeast Asia"
    },
    @{ 
        name = "onprem.datacenter1"
        description = "On-Premises Datacenter 1"
    }
)

# Load from config file if provided
if ($ConfigFile -and (Test-Path $ConfigFile)) {
    Write-Host "Loading network zones from: $ConfigFile" -ForegroundColor Cyan
    $networkZones = Get-Content $ConfigFile | ConvertFrom-Json
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Dynatrace Network Zone Creation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Tenant: $TenantUrl" -ForegroundColor White
Write-Host "Zones to create: $($networkZones.Count)`n" -ForegroundColor White

# Display zones
Write-Host "Network Zones:" -ForegroundColor Yellow
$networkZones | ForEach-Object {
    Write-Host "  - $($_.name)" -ForegroundColor White
    Write-Host "    $($_.description)" -ForegroundColor Gray
}

Write-Host ""

# Test API connection first
Write-Host "Testing API connection..." -ForegroundColor Yellow
try {
    $testUrl = "$TenantUrl/api/v2/networkZones"
    $existingZones = Invoke-RestMethod -Uri $testUrl -Method Get -Headers $headers -ErrorAction Stop
    Write-Host "✓ API connection successful" -ForegroundColor Green
    Write-Host "  Existing zones: $($existingZones.networkZones.Count)`n" -ForegroundColor Gray
}
catch {
    Write-Host "✗ API connection failed" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Check your API token and tenant URL`n" -ForegroundColor Yellow
    exit 1
}

# Confirm before proceeding
$confirmation = Read-Host "Proceed with network zone creation? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Create each network zone
$successCount = 0
$failCount = 0
$results = @()

foreach ($zone in $networkZones) {
    Write-Host "Creating: $($zone.name)" -ForegroundColor Cyan
    
    $url = "$TenantUrl/api/v2/networkZones/$($zone.name)"
    
    $body = @{
        "description" = $zone.description
        "enabled"     = $true
    } | ConvertTo-Json -Depth 2
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $body -ErrorAction Stop
        
        Write-Host "  ✓ Created successfully" -ForegroundColor Green
        
        $results += [PSCustomObject]@{
            Name = $zone.name
            Description = $zone.description
            Status = "Success"
            Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        
        $successCount++
    }
    catch {
        $errorMessage = $_.Exception.Message
        
        # Check if zone already exists
        if ($_.Exception.Response.StatusCode.value__ -eq 400) {
            Write-Host "  ⚠ Zone may already exist" -ForegroundColor Yellow
            $errorMessage = "Already exists or validation error"
        }
        else {
            Write-Host "  ✗ Failed to create" -ForegroundColor Red
        }
        
        Write-Host "    Error: $errorMessage" -ForegroundColor Gray
        
        $results += [PSCustomObject]@{
            Name = $zone.name
            Description = $zone.description
            Status = "Failed"
            Error = $errorMessage
            Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        
        $failCount++
    }
    
    Start-Sleep -Milliseconds 500
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total zones:    $($networkZones.Count)" -ForegroundColor White
Write-Host "Created:        $successCount" -ForegroundColor Green
Write-Host "Failed:         $failCount" -ForegroundColor $(if($failCount -gt 0){"Red"}else{"Green"})

if ($successCount -gt 0) {
    Write-Host "`nSuccessfully created zones:" -ForegroundColor Green
    $results | Where-Object { $_.Status -eq "Success" } | ForEach-Object {
        Write-Host "  ✓ $($_.Name)" -ForegroundColor Green
    }
}

if ($failCount -gt 0) {
    Write-Host "`nFailed zones:" -ForegroundColor Red
    $results | Where-Object { $_.Status -eq "Failed" } | ForEach-Object {
        Write-Host "  ✗ $($_.Name) - $($_.Error)" -ForegroundColor Red
    }
}

Write-Host "`nVerify in Dynatrace UI:" -ForegroundColor Cyan
Write-Host "$TenantUrl/ui/settings/builtin:deployment.management.network-zones`n" -ForegroundColor Gray

# Export results
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = "NetworkZones_Creation_$timestamp.csv"
$results | Export-Csv -Path $reportPath -NoTypeInformation
Write-Host "Results exported to: $reportPath" -ForegroundColor Cyan

exit $(if($failCount -eq 0){0}else{1})
