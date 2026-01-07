Import-Module $PSScriptRoot\AzLogging.ps1

# Dynatrace environment URLs
$DynatraceEnvironments = @{
    'NonProd' = 'https://activegate01.live.dynatrace.com'
    'Prod'    = 'https://activegate02.live.dynatrace.com'
}

$ErrorActionPreference = 'Continue'

<#
.SYNOPSIS
    Makes authenticated API requests to Dynatrace

.DESCRIPTION
    Constructs and executes authenticated REST API calls to Dynatrace using API token authentication
#>
function Invoke-DynatraceAPI {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [string]$HttpVerb,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourcePath,
        
        [Parameter(Mandatory = $false)]
        [string]$QueryParams = '',
        
        [Parameter(Mandatory = $false)]
        [object]$Data,
        
        [Parameter(Mandatory = $true)]
        [string]$ApiToken,
        
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl
    )
    
    # Construct URL
    $url = $BaseUrl + $ResourcePath + $QueryParams
    
    # Construct Headers
    $headers = @{
        'Authorization' = "Api-Token $ApiToken"
        'Content-Type'  = 'application/json'
    }
    
    Write-Debug "Uri: $url"
    Write-Debug "Method: $HttpVerb"
    
    # Prepare request parameters
    $requestParams = @{
        Uri     = $url
        Method  = $HttpVerb
        Headers = $headers
    }
    
    # Add body if data is provided
    if ($Data) {
        $jsonData = $Data | ConvertTo-Json -Depth 10
        $requestParams['Body'] = $jsonData
        Write-Debug "Body: $jsonData"
    }
    
    # Make Request
    try {
        $response = Invoke-RestMethod @requestParams
        Write-Verbose "API Response: $($response | ConvertTo-Json -Depth 5)"
        return $response
    }
    catch {
        Write-Error "API Request Failed: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Retrieves Dynatrace entity ID for a given server hostname

.DESCRIPTION
    Queries Dynatrace to find the entity ID for a server by hostname
#>
function Get-DynatraceEntityId {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServerName,
        
        [Parameter(Mandatory = $true)]
        [string]$ApiToken,
        
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl
    )
    
    # Query for host entity
    $resourcePath = '/api/v2/entities'
    $queryParams = "?entitySelector=type(`"HOST`"),entityName.equals(`"$ServerName`")&fields=+properties"
    
    try {
        $response = Invoke-DynatraceAPI -HttpVerb 'GET' -ResourcePath $resourcePath -QueryParams $queryParams -ApiToken $ApiToken -BaseUrl $BaseUrl
        
        if ($response.entities -and $response.entities.Count -gt 0) {
            return $response.entities[0].entityId
        }
        else {
            Write-Warning "No entity found for server: $ServerName"
            return $null
        }
    }
    catch {
        Write-Warning "Failed to retrieve entity ID for $ServerName : $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Finds existing maintenance window for a server

.DESCRIPTION
    Searches for active maintenance windows that include the specified server
#>
function Get-ExistingMaintenanceWindow {
    param (
        [Parameter(Mandatory = $true)]
        [string]$EntityId,
        
        [Parameter(Mandatory = $true)]
        [string]$ApiToken,
        
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl
    )
    
    $resourcePath = '/api/v2/settings/objects'
    $queryParams = "?schemaIds=builtin:alerting.maintenance-window&fields=value,objectId"
    
    try {
        $response = Invoke-DynatraceAPI -HttpVerb 'GET' -ResourcePath $resourcePath -QueryParams $queryParams -ApiToken $ApiToken -BaseUrl $BaseUrl
        
        # Find maintenance window that includes this entity
        foreach ($item in $response.items) {
            if ($item.value.scope -and $item.value.scope.entities -contains $EntityId) {
                # Check if it's currently active or scheduled
                $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                $schedule = $item.value.schedule
                
                if ($schedule.type -eq 'ONCE') {
                    $start = $schedule.onceRecurrence.startTime
                    $end = $schedule.onceRecurrence.endTime
                    
                    if ($now -ge $start -and $now -le $end) {
                        return $item
                    }
                }
            }
        }
        
        return $null
    }
    catch {
        Write-Warning "Failed to retrieve existing maintenance windows: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Sets Dynatrace Maintenance Window (SDT equivalent)

.DESCRIPTION
    Creates, extends, or ends maintenance windows in Dynatrace for specified servers.
    Suppresses alerts during maintenance while preserving critical alerts.
    
    This function mirrors the LogicMonitor SDT functionality for Dynatrace.

.PARAMETER Action
    Start - Creates new maintenance window (default 6 hours)
    Extend - Extends existing maintenance window (adds 1 hour)
    End - Ends existing maintenance window immediately

.PARAMETER Servers
    Array of server hostnames to apply maintenance window to

.PARAMETER Environment
    Dynatrace environment: NonProd (activegate01) or Prod (activegate02)
    Defaults to NonProd if not specified

.EXAMPLE
    Set-DynatraceSDT -Action 'Start' -Servers @('SERVER01', 'SERVER02')
    
.EXAMPLE
    Set-DynatraceSDT -Action 'End' -Servers $Servers -Environment 'Prod'
#>
function Set-DynatraceSDT {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Start', 'Extend', 'End')]
        [string]$Action,
        
        [Parameter(Mandatory = $true)]
        [array]$Servers,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('NonProd', 'Prod')]
        [string]$Environment = 'NonProd'
    )
    
    # Get API token from environment variable
    $apiToken = if ($Environment -eq 'NonProd') {
        $env:DynatraceAPITokenNonProd
    }
    else {
        $env:DynatraceAPITokenProd
    }
    
    if (-not $apiToken) {
        Call-AzLogging -Type 'Warning' -Message "Dynatrace API Token not found for $Environment environment"
        Write-Warning "Dynatrace API Token not found in environment variable: DynatraceAPIToken$Environment"
        return
    }
    
    # Get base URL
    $baseUrl = $DynatraceEnvironments[$Environment]
    
    # Variable End time for each Action (matching LogicMonitor pattern)
    $RunTime = if ($Action -eq 'Start') { 6 } else { 1 }
    
    foreach ($Server in $Servers) {
        Write-Host "$($Action)ing Dynatrace maintenance window for $Server"
        
        # Get entity ID for the server
        $entityId = Get-DynatraceEntityId -ServerName $Server -ApiToken $apiToken -BaseUrl $baseUrl
        
        if (-not $entityId) {
            Call-AzLogging -Type 'Warning' -Message "Dynatrace: Skipping $Server - entity not found"
            Write-Warning "Skipping $Server - entity not found in Dynatrace"
            continue
        }
        
        Write-Verbose "Found entity ID: $entityId for $Server"
        
        # Calculate times in milliseconds (Unix epoch)
        $startTime = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $endTime = [DateTimeOffset]::UtcNow.AddHours($RunTime).ToUnixTimeMilliseconds()
        
        # Handle different actions
        switch ($Action) {
            'Start' {
                # Create new maintenance window
                $maintenanceWindow = @{
                    schemaId = 'builtin:alerting.maintenance-window'
                    scope    = 'environment'
                    value    = @{
                        enabled     = $true
                        generalProperties = @{
                            name                 = "Automated Maintenance - $Server"
                            description          = "Automated scheduled maintenance window created by pipeline"
                            maintenanceType      = 'PLANNED'
                            suppression          = 'DETECT_PROBLEMS_DONT_ALERT'
                            disableSyntheticMonitorExecution = $false
                        }
                        schedule    = @{
                            type           = 'ONCE'
                            onceRecurrence = @{
                                startTime = $startTime
                                endTime   = $endTime
                                timeZone  = 'UTC'
                            }
                        }
                        scope       = @{
                            entities = @($entityId)
                            matches  = @()
                        }
                        filters     = @(
                            @{
                                entityType = 'HOST'
                                entityTags = @()
                                managementZones = @()
                            }
                        )
                    }
                }
                
                try {
                    $response = Invoke-DynatraceAPI -HttpVerb 'POST' -ResourcePath '/api/v2/settings/objects' `
                        -Data @($maintenanceWindow) -ApiToken $apiToken -BaseUrl $baseUrl
                    
                    Write-Host "Dynatrace maintenance window created for $Server (Duration: $RunTime hours)"
                    Call-AzLogging -Type 'Info' -Message "Dynatrace maintenance window started for $Server in $Environment (Duration: $RunTime hours)"
                }
                catch {
                    Write-Host "Failed to create Dynatrace maintenance window for $Server"
                    Call-AzLogging -Type 'Error' -Message "Failed to start Dynatrace maintenance window for $Server : $($_.Exception.Message)"
                }
            }
            
            'Extend' {
                # Find existing maintenance window
                $existingWindow = Get-ExistingMaintenanceWindow -EntityId $entityId -ApiToken $apiToken -BaseUrl $baseUrl
                
                if ($existingWindow) {
                    # Extend the end time
                    $currentEndTime = $existingWindow.value.schedule.onceRecurrence.endTime
                    $newEndTime = $currentEndTime + ($RunTime * 3600000) # Convert hours to milliseconds
                    
                    $existingWindow.value.schedule.onceRecurrence.endTime = $newEndTime
                    
                    try {
                        $response = Invoke-DynatraceAPI -HttpVerb 'PUT' -ResourcePath "/api/v2/settings/objects/$($existingWindow.objectId)" `
                            -Data $existingWindow.value -ApiToken $apiToken -BaseUrl $baseUrl
                        
                        Write-Host "Dynatrace maintenance window extended for $Server (Added: $RunTime hours)"
                        Call-AzLogging -Type 'Info' -Message "Dynatrace maintenance window extended for $Server in $Environment"
                    }
                    catch {
                        Write-Host "Failed to extend Dynatrace maintenance window for $Server"
                        Call-AzLogging -Type 'Warning' -Message "Failed to extend Dynatrace maintenance window for $Server"
                    }
                }
                else {
                    Call-AzLogging -Type 'Warning' -Message "No active Dynatrace maintenance window found for $Server to extend"
                    Write-Warning "No active maintenance window found for $Server to extend"
                }
            }
            
            'End' {
                # Find and delete existing maintenance window
                $existingWindow = Get-ExistingMaintenanceWindow -EntityId $entityId -ApiToken $apiToken -BaseUrl $baseUrl
                
                if ($existingWindow) {
                    try {
                        $response = Invoke-DynatraceAPI -HttpVerb 'DELETE' -ResourcePath "/api/v2/settings/objects/$($existingWindow.objectId)" `
                            -ApiToken $apiToken -BaseUrl $baseUrl
                        
                        Write-Host "Dynatrace maintenance window ended for $Server"
                        Call-AzLogging -Type 'Info' -Message "Dynatrace maintenance window ended for $Server in $Environment"
                    }
                    catch {
                        Write-Host "Failed to end Dynatrace maintenance window for $Server"
                        Call-AzLogging -Type 'Warning' -Message "Failed to end Dynatrace maintenance window for $Server"
                    }
                }
                else {
                    Call-AzLogging -Type 'Warning' -Message "No active Dynatrace maintenance window found for $Server to end"
                    Write-Warning "No active maintenance window found for $Server to end"
                }
            }
        }
    }
}

