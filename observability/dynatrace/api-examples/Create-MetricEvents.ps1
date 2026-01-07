<#
.SYNOPSIS
    Creates Dynatrace metric events for custom alerting thresholds

.DESCRIPTION
    Automates the creation of metric events in Dynatrace for monitoring
    infrastructure metrics with custom thresholds. This example creates
    disk space alerts at multiple severity levels.
    
    Demonstrates:
    - Settings API v2 usage
    - Metric selector syntax
    - Multi-threshold alerting
    - Entity filtering with tags

.PARAMETER ApiToken
    Dynatrace API token with settings.write and settings.read permissions

.PARAMETER TenantUrl
    Dynatrace tenant URL (e.g., https://abc12345.live.dynatrace.com)

.PARAMETER Environment
    Environment filter (Production, Development, etc.)

.EXAMPLE
    .\Create-MetricEvents.ps1 -ApiToken "dt0c01.ABC123..." -TenantUrl "https://abc12345.live.dynatrace.com" -Environment "Production"

.NOTES
    Author: Platform SRE Team
    API Documentation: https://www.dynatrace.com/support/help/dynatrace-api/environment-api/settings
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ApiToken,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantUrl,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Production", "Development", "Staging", "All")]
    [string]$Environment = "Production"
)

# Remove trailing slash
$TenantUrl = $TenantUrl.TrimEnd('/')

# Configuration
$schemaId = "builtin:anomaly-detection.metric-events"

# Headers
$headers = @{
    "Authorization" = "Api-Token $ApiToken"
    "Content-Type" = "application/json; charset=utf-8"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Dynatrace Metric Events Creation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Tenant:      $TenantUrl" -ForegroundColor White
Write-Host "Environment: $Environment`n" -ForegroundColor White

# Build metric selector based on environment
$envFilter = switch ($Environment) {
    "Production"  { 'tag(~"[Azure]Environment:Production~")' }
    "Development" { 'tag(~"[Azure]Environment:Development~")' }
    "Staging"     { 'tag(~"[Azure]Environment:Staging~")' }
    "All"         { '' }
}

$metricSelector = if ($envFilter) {
    "builtin:host.disk.usedPct:filter(in(`"dt.entity.host`",entitySelector(`"type(HOST),$envFilter`")))"
} else {
    "builtin:host.disk.usedPct"
}

Write-Host "Metric Selector:" -ForegroundColor Yellow
Write-Host "  $metricSelector`n" -ForegroundColor Gray

# Test API connection
Write-Host "Testing API connection..." -ForegroundColor Yellow
try {
    $schemaTest = Invoke-RestMethod -Uri "$TenantUrl/api/v2/settings/schemas/$schemaId" `
        -Headers $headers -ErrorAction Stop
    Write-Host "✓ API connection successful" -ForegroundColor Green
    Write-Host "✓ Schema '$schemaId' validated`n" -ForegroundColor Green
}
catch {
    Write-Host "✗ API connection failed" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Verify API token has settings.read and settings.write permissions`n" -ForegroundColor Yellow
    exit 1
}

# Define metric events with different severity levels
$metricEvents = @(
    @{
        Summary = "Disk Space Warning - 85%"
        Threshold = 85.0
        EventType = "RESOURCE"
        Title = "Disk Space Warning 85%"
        Description = "Disk space on {dims:dt.entity.host} drive {dims:dt.entity.disk} is at {alert_condition}% (Warning threshold: >=85%)"
        Severity = "Warning"
    },
    @{
        Summary = "Disk Space Error - 90%"
        Threshold = 90.0
        EventType = "ERROR"
        Title = "Disk Space Error 90%"
        Description = "Disk space on {dims:dt.entity.host} drive {dims:dt.entity.disk} is at {alert_condition}% (Error threshold: >=90%)"
        Severity = "Error"
    },
    @{
        Summary = "Disk Space Critical - 95%"
        Threshold = 95.0
        EventType = "AVAILABILITY"
        Title = "Disk Space Critical 95%"
        Description = "Disk space on {dims:dt.entity.host} drive {dims:dt.entity.disk} is at {alert_condition}% (Critical threshold: >=95%)"
        Severity = "Critical"
    }
)

Write-Host "Metric Events to Create:" -ForegroundColor Yellow
$metricEvents | ForEach-Object {
    Write-Host "  - $($_.Summary) [$($_.Severity)]" -ForegroundColor White
}
Write-Host ""

# Confirm
$confirmation = Read-Host "Proceed with metric event creation? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Create each metric event
$successCount = 0
$failCount = 0
$createdEvents = @()

foreach ($event in $metricEvents) {
    Write-Host "Creating: $($event.Summary)" -ForegroundColor Cyan
    
    # Build payload
    $payload = @{
        schemaId = $schemaId
        scope = "environment"
        value = @{
            enabled = $true
            summary = $event.Summary
            queryDefinition = @{
                type = "METRIC_SELECTOR"
                metricSelector = $metricSelector
            }
            modelProperties = @{
                type = "STATIC_THRESHOLD"
                threshold = $event.Threshold
                alertOnNoData = $false
                alertCondition = "ABOVE"
                violatingSamples = 3
                samples = 5
                dealertingSamples = 5
            }
            eventTemplate = @{
                title = $event.Title
                description = $event.Description
                eventType = $event.EventType
                davisMerge = $true
            }
            eventEntityDimensionKey = "dt.entity.disk"
        }
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri "$TenantUrl/api/v2/settings/objects" `
            -Method POST `
            -Headers $headers `
            -Body $payload `
            -ErrorAction Stop
        
        Write-Host "  ✓ Created successfully" -ForegroundColor Green
        Write-Host "    Object ID: $($response.objectId)" -ForegroundColor Gray
        Write-Host "    Threshold: $($event.Threshold)%`n" -ForegroundColor Gray
        
        $createdEvents += [PSCustomObject]@{
            Summary = $event.Summary
            Threshold = $event.Threshold
            Severity = $event.Severity
            ObjectId = $response.objectId
            Status = "Success"
            Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        
        $successCount++
    }
    catch {
        Write-Host "  ✗ Failed to create" -ForegroundColor Red
        
        $errorMessage = $_.Exception.Message
        
        # Parse error details if available
        if ($_.ErrorDetails.Message) {
            try {
                $errorDetail = $_.ErrorDetails.Message | ConvertFrom-Json
                if ($errorDetail.error.message) {
                    $errorMessage = $errorDetail.error.message
                }
            }
            catch {
                # Couldn't parse error details
            }
        }
        
        Write-Host "    Error: $errorMessage`n" -ForegroundColor Gray
        
        $createdEvents += [PSCustomObject]@{
            Summary = $event.Summary
            Threshold = $event.Threshold
            Severity = $event.Severity
            ObjectId = $null
            Status = "Failed"
            Error = $errorMessage
            Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        
        $failCount++
    }
    
    Start-Sleep -Seconds 1
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total events:   $($metricEvents.Count)" -ForegroundColor White
Write-Host "Created:        $successCount" -ForegroundColor Green
Write-Host "Failed:         $failCount" -ForegroundColor $(if($failCount -gt 0){"Red"}else{"Green"})

if ($successCount -gt 0) {
    Write-Host "`nSuccessfully Created:" -ForegroundColor Green
    $createdEvents | Where-Object { $_.Status -eq "Success" } | ForEach-Object {
        Write-Host "  ✓ $($_.Summary)" -ForegroundColor Green
        Write-Host "    ID: $($_.ObjectId)" -ForegroundColor Gray
    }
}

if ($failCount -gt 0) {
    Write-Host "`nFailed:" -ForegroundColor Red
    $createdEvents | Where-Object { $_.Status -eq "Failed" } | ForEach-Object {
        Write-Host "  ✗ $($_.Summary)" -ForegroundColor Red
        Write-Host "    Error: $($_.Error)" -ForegroundColor Gray
    }
}

Write-Host "`nVerify in Dynatrace UI:" -ForegroundColor Cyan
Write-Host "$TenantUrl/ui/settings/anomalydetection/metricevents`n" -ForegroundColor Gray

# Export results
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = "MetricEvents_Creation_$timestamp.csv"
$createdEvents | Export-Csv -Path $reportPath -NoTypeInformation
Write-Host "Results exported to: $reportPath" -ForegroundColor Cyan

if ($successCount -eq $metricEvents.Count) {
    Write-Host "`n✓ All metric events created successfully!" -ForegroundColor Green
}

exit $(if($failCount -eq 0){0}else{1})
