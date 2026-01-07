<#
.SYNOPSIS
    Azure VM Tag Management - Apply tags based on naming patterns with production-grade controls

.DESCRIPTION
    Production-ready Azure VM tagging automation with:
    - Native -WhatIf support via ShouldProcess
    - Parameter-based modes (no interactive prompts - CI/CD friendly)
    - Regex pattern matching for precise naming conventions
    - Idempotent operations with -OnlyIfMissing flag
    - Structured logging and pipeline output
    - CSV export for audit trails
    
.PARAMETER Mode
    Operation mode:
    - List: Display all VMs and their current tags (read-only)
    - Apply: Add tags to VMs based on naming patterns
    - Report: Generate detailed CSV report without changes
    Default: List

.PARAMETER SubscriptionId
    Specific Azure subscription ID to process. If not specified, processes all accessible subscriptions.

.PARAMETER ResourceGroupName
    Limit operations to a specific resource group.

.PARAMETER VmNamePattern
    Filter VMs by name pattern (supports wildcards). Example: 'PROD-*'
    Default: '*' (all VMs)

.PARAMETER OnlyIfMissing
    Only add tags if they don't already exist. Preserves existing tag values.
    Useful for initial tagging without overwriting manual changes.

.PARAMETER Force
    Skip confirmation prompts. Use with caution in production.

.PARAMETER ExportPath
    Path for CSV export. Default: C:\temp\Azure_VM_Tags_<timestamp>.csv

.PARAMETER TenantId
    Azure Tenant ID to connect to. If not specified, uses default tenant.

.EXAMPLE
    .\Set-AzureVmTagsFromPolicy.ps1 -Mode List
    
    List all VMs with their current tags across all subscriptions.

.EXAMPLE
    .\Set-AzureVmTagsFromPolicy.ps1 -Mode Apply -WhatIf
    
    Preview what tags would be applied without making any changes.

.EXAMPLE
    .\Set-AzureVmTagsFromPolicy.ps1 -Mode Apply -SubscriptionId 'abc-123' -Force
    
    Apply tags to VMs in specific subscription without confirmation prompts.

.EXAMPLE
    .\Set-AzureVmTagsFromPolicy.ps1 -Mode Apply -VmNamePattern 'PROD-*' -OnlyIfMissing
    
    Add tags only to PROD VMs and only if tags don't already exist.

.EXAMPLE
    .\Set-AzureVmTagsFromPolicy.ps1 -Mode Apply -ResourceGroupName 'production-rg'
    
    Apply tags only to VMs in a specific resource group.

.NOTES
    Author: Platform SRE Team
    Version: 2.0
    Requires: Az.Accounts, Az.Compute, Az.Resources
    Permissions: Tag Contributor or Contributor on target resources
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('List', 'Apply', 'Report')]
    [string]$Mode = 'List',
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$VmNamePattern = '*',
    
    [Parameter(Mandatory=$false)]
    [switch]$OnlyIfMissing,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "C:\temp\Azure_VM_Tags_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    
    [Parameter(Mandatory=$false)]
    [string]$TenantId
)

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )
    
    $colors = @{
        'INFO' = 'Cyan'
        'SUCCESS' = 'Green'
        'WARNING' = 'Yellow'
        'ERROR' = 'Red'
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colors[$Level]
}

function Test-TagExists {
    param(
        [hashtable]$ExistingTags,
        [string]$TagKey
    )
    
    return $ExistingTags.ContainsKey($TagKey)
}

#endregion

#region Module Installation

Write-Log "Checking required Azure modules..." -Level INFO

$requiredModules = @('Az.Accounts', 'Az.Compute', 'Az.Resources')
foreach ($module in $requiredModules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Log "Installing $module module..." -Level WARNING
        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
    }
}

Import-Module Az.Accounts, Az.Compute, Az.Resources -ErrorAction Stop

#endregion

#region Export Directory Setup

$exportDir = Split-Path $ExportPath -Parent
if (!(Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
    Write-Log "Created export directory: $exportDir" -Level INFO
}

#endregion

#region Azure Authentication

Write-Log "Connecting to Azure..." -Level INFO

try {
    if ($TenantId) {
        Connect-AzAccount -Tenant $TenantId -ErrorAction Stop | Out-Null
    } else {
        Connect-AzAccount -ErrorAction Stop | Out-Null
    }
    Write-Log "Successfully connected to Azure" -Level SUCCESS
}
catch {
    Write-Log "Failed to connect to Azure: $($_.Exception.Message)" -Level ERROR
    exit 1
}

#endregion

#region Subscription Selection

if ($SubscriptionId) {
    $subscriptions = @(Get-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop)
    Write-Log "Processing specific subscription: $($subscriptions[0].Name)" -Level INFO
} else {
    $subscriptions = Get-AzSubscription
    Write-Log "Found $($subscriptions.Count) subscription(s)" -Level INFO
}

#endregion

#region Naming Patterns (Regex-based)

# Define naming patterns with regex for precise matching
$namingPatterns = @(
    @{ Regex = '^PROD-'; Tags = @{ Environment = 'Production'; CostCenter = 'Production' } }
    @{ Regex = '^UAT-'; Tags = @{ Environment = 'UAT'; CostCenter = 'Non-Production' } }
    @{ Regex = '^DEV-'; Tags = @{ Environment = 'Development'; CostCenter = 'Non-Production' } }
    @{ Regex = '-WEB-'; Tags = @{ Role = 'WebServer'; Tier = 'Web' } }
    @{ Regex = '-APP-'; Tags = @{ Role = 'ApplicationServer'; Tier = 'Application' } }
    @{ Regex = '-SQL-'; Tags = @{ Role = 'DatabaseServer'; Tier = 'Data' } }
    @{ Regex = '-DB-'; Tags = @{ Role = 'DatabaseServer'; Tier = 'Data' } }
    @{ Regex = '-DC-'; Tags = @{ Role = 'DomainController'; Tier = 'Infrastructure' } }
    @{ Regex = '-MGMT-'; Tags = @{ Role = 'Management'; Tier = 'Infrastructure' } }
    @{ Regex = '-JUMP-'; Tags = @{ Role = 'JumpServer'; Tier = 'Infrastructure' } }
    @{ Regex = '-BASTION-'; Tags = @{ Role = 'Bastion'; Tier = 'Infrastructure' } }
)

Write-Log "Loaded $($namingPatterns.Count) naming pattern rules" -Level INFO

#endregion

#region Main Execution Logic

$allResults = @()

foreach ($subscription in $subscriptions) {
    Write-Log "Processing subscription: $($subscription.Name)" -Level INFO
    Set-AzContext -SubscriptionId $subscription.Id | Out-Null
    
    # Get VMs with optional filtering
    $getVmParams = @{}
    if ($ResourceGroupName) {
        $getVmParams['ResourceGroupName'] = $ResourceGroupName
    }
    
    $vms = Get-AzVM @getVmParams | Where-Object { $_.Name -like $VmNamePattern }
    Write-Log "Found $($vms.Count) VM(s) matching criteria" -Level INFO
    
    foreach ($vm in $vms) {
        $vmName = $vm.Name
        
        # For List mode, just collect and display
        if ($Mode -eq 'List' -or $Mode -eq 'Report') {
            $tags = $vm.Tags
            $tagString = if ($tags) {
                ($tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "; "
            } else {
                "No tags"
            }
            
            $vmInfo = [PSCustomObject]@{
                SubscriptionName = $subscription.Name
                VMName           = $vmName
                ResourceGroup    = $vm.ResourceGroupName
                Location         = $vm.Location
                Tags             = $tagString
                TagCount         = if ($tags) { $tags.Count } else { 0 }
            }
            
            $allResults += $vmInfo
            
            if ($Mode -eq 'List') {
                Write-Host "`nVM: $vmName" -ForegroundColor White
                Write-Host "  Resource Group: $($vm.ResourceGroupName)" -ForegroundColor Gray
                Write-Host "  Tags: $tagString" -ForegroundColor Cyan
            }
            
            continue
        }
        
        # For Apply mode, match patterns and apply tags
        if ($Mode -eq 'Apply') {
            $tagsToAdd = @{}
            $matchedPatterns = @()
            
            # Check each regex pattern
            foreach ($pattern in $namingPatterns) {
                if ($vmName -match $pattern.Regex) {
                    foreach ($tagKey in $pattern.Tags.Keys) {
                        $tagsToAdd[$tagKey] = $pattern.Tags[$tagKey]
                    }
                    $matchedPatterns += $pattern.Regex
                }
            }
            
            if ($tagsToAdd.Count -eq 0) {
                Write-Log "No pattern match for VM: $vmName" -Level WARNING
                continue
            }
            
            # Get existing tags
            $existingTags = if ($vm.Tags) { $vm.Tags } else { @{} }
            
            # Apply idempotency logic
            $tagsToApply = @{}
            foreach ($key in $tagsToAdd.Keys) {
                if ($OnlyIfMissing -and (Test-TagExists -ExistingTags $existingTags -TagKey $key)) {
                    Write-Log "Tag '$key' already exists on $vmName, skipping (OnlyIfMissing)" -Level INFO
                    continue
                }
                $tagsToApply[$key] = $tagsToAdd[$key]
            }
            
            if ($tagsToApply.Count -eq 0) {
                Write-Log "All tags already exist on $vmName, skipping" -Level INFO
                continue
            }
            
            # Native WhatIf support with ShouldProcess
            $tagString = ($tagsToApply.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "
            
            if ($PSCmdlet.ShouldProcess($vmName, "Merge tags: $tagString")) {
                try {
                    # Merge tags
                    foreach ($key in $tagsToApply.Keys) {
                        $existingTags[$key] = $tagsToApply[$key]
                    }
                    
                    # Apply tags
                    Update-AzTag -ResourceId $vm.Id -Tag $existingTags -Operation Merge -ErrorAction Stop | Out-Null
                    
                    Write-Log "Successfully tagged $vmName with: $tagString" -Level SUCCESS
                    
                    $allResults += [PSCustomObject]@{
                        SubscriptionName = $subscription.Name
                        VMName           = $vmName
                        ResourceGroup    = $vm.ResourceGroupName
                        PatternsMatched  = $matchedPatterns -join ', '
                        TagsApplied      = $tagString
                        Status           = 'Success'
                    }
                }
                catch {
                    Write-Log "Failed to tag $vmName : $($_.Exception.Message)" -Level ERROR
                    
                    $allResults += [PSCustomObject]@{
                        SubscriptionName = $subscription.Name
                        VMName           = $vmName
                        ResourceGroup    = $vm.ResourceGroupName
                        PatternsMatched  = $matchedPatterns -join ', '
                        TagsApplied      = 'Failed'
                        Status           = "Error: $($_.Exception.Message)"
                    }
                }
            }
        }
    }
}

#endregion

#region Export Results

if ($allResults.Count -gt 0) {
    # Output to pipeline
    $allResults | ForEach-Object { Write-Output $_ }
    
    # Export to CSV
    $allResults | Export-Csv -Path $ExportPath -NoTypeInformation
    Write-Log "Results exported to: $ExportPath" -Level SUCCESS
} else {
    Write-Log "No results to export" -Level WARNING
}

#endregion

Write-Log "Script execution completed!" -Level SUCCESS
