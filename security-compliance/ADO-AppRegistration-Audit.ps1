#==============================================================================
# CONFIGURATION VARIABLES - MODIFY THESE AS NEEDED
#==============================================================================

# Azure DevOps Configuration
$organization = "your-organization"

# App Registration IDs to check (up to 6) - Set to $null or "" to ignore
$AppRegistrationId1 = "12345678-1234-1234-1234-123456789001"  # Example App Registration 1
$AppRegistrationId2 = "12345678-1234-1234-1234-123456789002"  # Example App Registration 2
$AppRegistrationId3 = "12345678-1234-1234-1234-123456789003"  # Example App Registration 3
$AppRegistrationId4 = ""  # Add fourth App Registration ID here if needed
$AppRegistrationId5 = ""  # Add fifth App Registration ID here if needed
$AppRegistrationId6 = ""  # Add sixth App Registration ID here if needed


# Optional: Friendly names for each App Registration (for reporting)
$AppRegistrationNames = @{
    "12345678-1234-1234-1234-123456789001" = "Platform-Automation-App"
    "12345678-1234-1234-1234-123456789002" = "User-Invite-Automation"
    "12345678-1234-1234-1234-123456789003" = "Terraform-ServiceAccount-Prod"
    
    # Add more mappings as needed:
    # "your-app-registration-id" = "Friendly App Name"
}

# API Configuration
$apiVersion = "6.0"

# Output Configuration
$outputDirectory = "C:\temp"  # Output folder for reports
$exportToCsv = $true
$exportSummary = $true
$showProgress = $true
$showDetailedOutput = $true

# Colors for output (optional customization)
$colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "White"
    Detail = "Gray"
    Highlight = "Yellow"
}

#==============================================================================
# PAT TOKEN INPUT - SECURE PROMPT
#==============================================================================

Write-Host "🔐 Azure DevOps Personal Access Token Required" -ForegroundColor $colors.Warning
Write-Host "Please enter your PAT token (input will be hidden for security):" -ForegroundColor $colors.Info
$secureString = Read-Host "PAT Token" -AsSecureString
$PersonalAccessToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString))

# Validate PAT token was entered
if ([string]::IsNullOrWhiteSpace($PersonalAccessToken)) {
    Write-Host "❌ No PAT token provided. Exiting..." -ForegroundColor $colors.Error
    exit 1
}

Write-Host "✅ PAT token received" -ForegroundColor $colors.Success
Write-Host ""

#==============================================================================
# PREPARE APP REGISTRATION IDs TO CHECK
#==============================================================================

# Build array of non-null App Registration IDs
$appRegistrationIds = @()
$appIdVariables = @($AppRegistrationId1, $AppRegistrationId2, $AppRegistrationId3, $AppRegistrationId4, $AppRegistrationId5)

foreach ($appId in $appIdVariables) {
    if (-not [string]::IsNullOrWhiteSpace($appId)) {
        $appRegistrationIds += $appId
    }
}

if ($appRegistrationIds.Count -eq 0) {
    Write-Host "❌ No App Registration IDs configured. Please set at least one AppRegistrationId variable." -ForegroundColor $colors.Error
    exit 1
}

Write-Host "🔍 Configured to check $($appRegistrationIds.Count) App Registration(s):" -ForegroundColor $colors.Info
foreach ($appId in $appRegistrationIds) {
    $friendlyName = if ($AppRegistrationNames.ContainsKey($appId)) { $AppRegistrationNames[$appId] } else { "Unknown App" }
    Write-Host "  - $appId ($friendlyName)" -ForegroundColor $colors.Detail
}
Write-Host ""

#==============================================================================
# MAIN SCRIPT EXECUTION
#==============================================================================

# Create output directory if it doesn't exist
if (-not (Test-Path -Path $outputDirectory)) {
    Write-Host "📁 Creating output directory: $outputDirectory" -ForegroundColor $colors.Warning
    try {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        Write-Host "✅ Directory created successfully" -ForegroundColor $colors.Success
    } catch {
        Write-Error "❌ Failed to create directory: $($_.Exception.Message)"
        Write-Host "Falling back to current directory for output files" -ForegroundColor $colors.Warning
        $outputDirectory = "."
    }
} else {
    Write-Host "📁 Using existing output directory: $outputDirectory" -ForegroundColor $colors.Info
}

# Create authentication header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PersonalAccessToken"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
    'Content-Type' = 'application/json'
}

# Build API URIs
$projectsUri = "https://dev.azure.com/$organization/_apis/projects?api-version=$apiVersion"

Write-Host "🔍 Starting Azure DevOps App Registration Usage Audit..." -ForegroundColor $colors.Header
Write-Host "Organization: $organization" -ForegroundColor $colors.Info
Write-Host "Output Directory: $outputDirectory" -ForegroundColor $colors.Info
Write-Host "=" * 80

# Test PAT token by fetching projects
Write-Host "📋 Testing PAT token and fetching projects..." -ForegroundColor $colors.Warning
try {
    $projects = (Invoke-RestMethod -Uri $projectsUri -Headers $headers).value
    Write-Host "✅ PAT token valid! Found $($projects.Count) projects to scan" -ForegroundColor $colors.Success
} catch {
    Write-Host "❌ PAT token test failed: $($_.Exception.Message)" -ForegroundColor $colors.Error
    Write-Host "Please check:" -ForegroundColor $colors.Warning
    Write-Host "  - PAT token is correct and not expired" -ForegroundColor $colors.Info
    Write-Host "  - PAT has required permissions (Project and team: Read, Service connections: Read)" -ForegroundColor $colors.Info
    Write-Host "  - Organization name is correct: $organization" -ForegroundColor $colors.Info
    exit 1
}

# Initialize results arrays - one for each App Registration
$allResults = @{}
$summaryResults = @{}
foreach ($appId in $appRegistrationIds) {
    $allResults[$appId] = @()
    $summaryResults[$appId] = @{
        AppId = $appId
        FriendlyName = if ($AppRegistrationNames.ContainsKey($appId)) { $AppRegistrationNames[$appId] } else { "Unknown App" }
        ProjectsFound = @()
        TotalConnections = 0
    }
}

$projectCount = 0
$totalServiceConnections = 0

# Check each project for service connections
foreach ($project in $projects) {
    $projectCount++
    
    if ($showProgress) {
        Write-Progress -Activity "Scanning Projects for App Registration Usage" -Status "Project $projectCount of $($projects.Count): $($project.name)" -PercentComplete (($projectCount / $projects.Count) * 100)
    }
    
    if ($showDetailedOutput) {
        Write-Host "🔎 [$projectCount/$($projects.Count)] Checking: $($project.name)" -ForegroundColor $colors.Header
    }
    
    # Build service connections URI for this project
    $serviceConnectionsUri = "https://dev.azure.com/$organization/$($project.name)/_apis/serviceendpoint/endpoints?api-version=$apiVersion"
    
    try {
        $serviceConnections = (Invoke-RestMethod -Uri $serviceConnectionsUri -Headers $headers).value
        $totalServiceConnections += $serviceConnections.Count
        
        $projectMatches = @{}
        foreach ($appId in $appRegistrationIds) {
            $projectMatches[$appId] = 0
        }
        
        foreach ($sc in $serviceConnections) {
            # Check if this service connection uses any of our app registrations
            foreach ($appId in $appRegistrationIds) {
                if ($sc.authorization.parameters.serviceprincipalid -eq $appId) {
                    $projectMatches[$appId]++
                    
                    $friendlyName = if ($AppRegistrationNames.ContainsKey($appId)) { $AppRegistrationNames[$appId] } else { "Unknown App" }
                    
                    if ($showDetailedOutput) {
                        Write-Host "  ✅ MATCH FOUND: $($sc.name) (App: $friendlyName)" -ForegroundColor $colors.Success
                    }
                    
                    $result = [PSCustomObject]@{
                        AppRegistrationId = $appId
                        AppFriendlyName = $friendlyName
                        ProjectName = $project.name
                        ProjectId = $project.id
                        ServiceConnectionName = $sc.name
                        ServiceConnectionId = $sc.id
                        ServiceConnectionType = $sc.type
                        Description = $sc.description
                        CreatedBy = if($sc.createdBy) { $sc.createdBy.displayName } else { "Unknown" }
                        CreatedDate = if($sc.createdDate) { $sc.createdDate } else { "Unknown" }
                        Url = $sc.url
                        IsReady = $sc.isReady
                        IsShared = $sc.isShared
                        ProjectUrl = "https://dev.azure.com/$organization/$($project.name)/_settings/adminservices"
                    }
                    $allResults[$appId] += $result
                    
                    # Update summary
                    if ($project.name -notin $summaryResults[$appId].ProjectsFound) {
                        $summaryResults[$appId].ProjectsFound += $project.name
                    }
                    $summaryResults[$appId].TotalConnections++
                }
            }
        }
        
        if ($showDetailedOutput) {
            $totalMatches = ($projectMatches.Values | Measure-Object -Sum).Sum
            if ($totalMatches -eq 0) {
                Write-Host "  ❌ No matches (checked $($serviceConnections.Count) service connections)" -ForegroundColor $colors.Detail
            } else {
                Write-Host "  🎯 Found $totalMatches total matches in this project!" -ForegroundColor $colors.Warning
            }
        }
        
    } catch {
        Write-Warning "  ⚠️  Could not access service connections for project: $($project.name)"
        Write-Warning "     Error: $($_.Exception.Message)"
    }
}

# Clear progress bar and clean up sensitive data
if ($showProgress) {
    Write-Progress -Activity "Scanning Projects for App Registration Usage" -Completed
}

# Clear PAT token from memory for security
$PersonalAccessToken = $null
$secureString = $null

# Display results
Write-Host "`n" + "=" * 80
Write-Host "📊 APP REGISTRATION USAGE AUDIT SUMMARY" -ForegroundColor $colors.Warning
Write-Host "=" * 80
Write-Host "Total Projects Scanned: $($projects.Count)" -ForegroundColor $colors.Info
Write-Host "Total Service Connections Found: $totalServiceConnections" -ForegroundColor $colors.Info
Write-Host "App Registrations Checked: $($appRegistrationIds.Count)" -ForegroundColor $colors.Info

# Summary by App Registration
Write-Host "`n🔍 RESULTS BY APP REGISTRATION:" -ForegroundColor $colors.Header
foreach ($appId in $appRegistrationIds) {
    $summary = $summaryResults[$appId]
    $status = if ($summary.TotalConnections -gt 0) { $colors.Success } else { $colors.Error }
    $statusIcon = if ($summary.TotalConnections -gt 0) { "✅" } else { "❌" }
    
    Write-Host "`n$statusIcon App: $($summary.FriendlyName)" -ForegroundColor $status
    Write-Host "   ID: $($summary.AppId)" -ForegroundColor $colors.Detail
    Write-Host "   Service Connections: $($summary.TotalConnections)" -ForegroundColor $status
    Write-Host "   Projects: $($summary.ProjectsFound.Count)" -ForegroundColor $status
    
    if ($summary.ProjectsFound.Count -gt 0) {
        Write-Host "   Found in: $($summary.ProjectsFound -join ', ')" -ForegroundColor $colors.Info
    }
}

# Detailed results for each App Registration that has matches
$hasAnyMatches = $false
foreach ($appId in $appRegistrationIds) {
    if ($allResults[$appId].Count -gt 0) {
        $hasAnyMatches = $true
        $friendlyName = $summaryResults[$appId].FriendlyName
        
        Write-Host "`n" + "=" * 60
        Write-Host "📋 DETAILED RESULTS FOR: $friendlyName" -ForegroundColor $colors.Header
        Write-Host "App Registration ID: $appId" -ForegroundColor $colors.Detail
        Write-Host "=" * 60
        
        # Group by project for better display
        $groupedResults = $allResults[$appId] | Group-Object ProjectName
        
        foreach ($group in $groupedResults) {
            Write-Host "`n📁 Project: $($group.Name)" -ForegroundColor $colors.Header
            foreach ($connection in $group.Group) {
                Write-Host "   🔗 $($connection.ServiceConnectionName)" -ForegroundColor $colors.Info
                Write-Host "      Type: $($connection.ServiceConnectionType)" -ForegroundColor $colors.Detail
                Write-Host "      Created by: $($connection.CreatedBy)" -ForegroundColor $colors.Detail
                Write-Host "      Description: $($connection.Description)" -ForegroundColor $colors.Detail
                Write-Host "      Project Settings: $($connection.ProjectUrl)" -ForegroundColor $colors.Highlight
                Write-Host ""
            }
        }
    }
}

if (-not $hasAnyMatches) {
    Write-Host "`n❌ No service connections found using any of the configured App Registrations" -ForegroundColor $colors.Error
    Write-Host "This could mean:" -ForegroundColor $colors.Warning
    Write-Host "  - The App Registrations are not currently in use" -ForegroundColor $colors.Info
    Write-Host "  - The App Registration IDs are incorrect" -ForegroundColor $colors.Info
    Write-Host "  - Service connections are using different App Registrations" -ForegroundColor $colors.Info
}

# Export results
if ($exportToCsv -and $hasAnyMatches) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    # Combine all results for CSV export
    $allResultsCombined = @()
    foreach ($appId in $appRegistrationIds) {
        $allResultsCombined += $allResults[$appId]
    }
    
    $csvPath = Join-Path -Path $outputDirectory -ChildPath "ADO_AppRegistration_Usage_Report_$timestamp.csv"
    $allResultsCombined | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "📄 Detailed results exported to: $csvPath" -ForegroundColor $colors.Header
}

# Create summary report
if ($exportSummary -and $hasAnyMatches) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $summaryPath = Join-Path -Path $outputDirectory -ChildPath "ADO_AppRegistration_Summary_$timestamp.txt"
    
    $summaryContent = @"
Azure DevOps App Registration Usage Audit Report
Generated: $(Get-Date)
Organization: $organization
App Registrations Checked: $($appRegistrationIds.Count)

SUMMARY BY APP REGISTRATION:
"@

    foreach ($appId in $appRegistrationIds) {
        $summary = $summaryResults[$appId]
        $summaryContent += @"

- $($summary.FriendlyName)
  ID: $($summary.AppId)
  Service Connections: $($summary.TotalConnections)
  Projects: $($summary.ProjectsFound.Count)
  Projects Found In: $($summary.ProjectsFound -join ', ')
"@
    }

    $summaryContent += @"

DETAILED FINDINGS:
"@

    foreach ($appId in $appRegistrationIds) {
        if ($allResults[$appId].Count -gt 0) {
            $friendlyName = $summaryResults[$appId].FriendlyName
            $summaryContent += @"

$friendlyName ($appId):
"@
            $groupedResults = $allResults[$appId] | Group-Object ProjectName
            foreach ($group in $groupedResults) {
                $summaryContent += @"
  Project: $($group.Name)
"@
                foreach ($connection in $group.Group) {
                    $summaryContent += @"
    - $($connection.ServiceConnectionName) ($($connection.ServiceConnectionType))
      Created by: $($connection.CreatedBy)
      Description: $($connection.Description)
"@
                }
            }
        }
    }

    $summaryContent += @"

NEXT STEPS:
1. Review each service connection listed above
2. Verify if these App Registrations are still needed
3. Plan rotation/replacement if required
4. Update any pipelines that depend on these connections
5. Consider consolidating multiple App Registrations if possible
"@
    
    $summaryContent | Out-File -FilePath $summaryPath -Encoding UTF8
    Write-Host "📋 Summary report saved to: $summaryPath" -ForegroundColor $colors.Header
}

Write-Host "`n🏁 App Registration audit completed!" -ForegroundColor $colors.Success
