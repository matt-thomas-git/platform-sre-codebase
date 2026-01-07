param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "config/permissions-config.json",
    
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'uat', 'staging', 'production')]
    [string]$Environment,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('all', 'adGroupsOnly', 'azureADGroupsOnly', 'sqlPermissionsOnly', 'azureSQLPermissionsOnly')]
    [string]$OperationType = 'all',
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [switch]$AutoConfirm,
    
    [Parameter(Mandatory = $false)]
    [string]$AzureTenantId = "YOUR-TENANT-ID-HERE",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "."
)

# Helper function for safe confirmation in pipeline
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

Write-Host "=== SQL Permissions Management Pipeline Started ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Running User: $env:USERNAME"
Write-Host "Computer: $env:COMPUTERNAME"
Write-Host "Environment: $Environment"
Write-Host "Operation Type: $OperationType"
Write-Host "Dry Run: $DryRun"
Write-Host ""

# Load configuration
$configPath = Join-Path $PSScriptRoot $ConfigFile
if (-not (Test-Path $configPath)) {
    Write-Error "Configuration file not found: $configPath"
    exit 1
}

try {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    Write-Host "✓ Configuration loaded successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to load configuration: $($_.Exception.Message)"
    exit 1
}

# Validate environment exists in config
if (-not $config.environments.$Environment) {
    Write-Error "Environment '$Environment' not found in configuration"
    exit 1
}

$envConfig = $config.environments.$Environment
Write-Host "✓ Environment configuration validated" -ForegroundColor Green
Write-Host ""

# Initialize tracking variables
$results = @{
    ADGroups = @()
    AzureADGroups = @()
    SQLServers = @()
    AzureSQLServers = @()
    TotalSuccess = 0
    TotalFailed = 0
    StartTime = Get-Date
}

# Confirmation prompt
if (-not $AutoConfirm -and -not $DryRun) {
    Write-Host "=== OPERATION SUMMARY ===" -ForegroundColor Yellow
    Write-Host "Environment: $Environment"
    Write-Host "Operation Type: $OperationType"
    
    if ($OperationType -eq 'all' -or $OperationType -eq 'adGroupsOnly') {
        Write-Host "AD Groups to create: $($envConfig.adGroups.Count)"
    }
    if ($OperationType -eq 'all' -or $OperationType -eq 'azureADGroupsOnly') {
        Write-Host "Azure AD Groups to create: $($envConfig.azureADGroups.Count)"
    }
    if ($OperationType -eq 'all' -or $OperationType -eq 'sqlPermissionsOnly') {
        Write-Host "SQL Servers to configure: $($envConfig.sqlServers.Count)"
    }
    if ($OperationType -eq 'all' -or $OperationType -eq 'azureSQLPermissionsOnly') {
        Write-Host "Azure SQL Servers to configure: $($envConfig.azureSQLServers.Count)"
    }
    Write-Host ""
    
    $proceed = Get-SafeConfirmation "Proceed with SQL permissions management? (Y/N)"
    if (-not $proceed) {
        Write-Host "Operation cancelled by user" -ForegroundColor Yellow
        exit 0
    }
}

# ============================================================================
# ACTIVE DIRECTORY OPERATIONS
# ============================================================================
if ($OperationType -eq 'all' -or $OperationType -eq 'adGroupsOnly') {
    Write-Host "`n=== ACTIVE DIRECTORY OPERATIONS ===" -ForegroundColor Cyan
    
    if ($envConfig.adGroups.Count -eq 0) {
        Write-Host "No AD groups configured for this environment" -ForegroundColor Yellow
    } else {
        # Import AD module
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
            Write-Host "✓ Active Directory module loaded" -ForegroundColor Green
        } catch {
            Write-Error "Failed to load Active Directory module: $($_.Exception.Message)"
            $results.TotalFailed += $envConfig.adGroups.Count
            foreach ($group in $envConfig.adGroups) {
                $results.ADGroups += @{
                    GroupName = $group.name
                    Action = "Failed"
                    Message = "AD module not available"
                    Success = $false
                }
            }
        }
        
        if (Get-Module ActiveDirectory) {
            foreach ($group in $envConfig.adGroups) {
                Write-Host "`nProcessing AD Group: $($group.name)" -ForegroundColor Yellow
                
                try {
                    if ($DryRun) {
                        Write-Host "[DRY RUN] Would create AD group: $($group.name)" -ForegroundColor Cyan
                        Write-Host "  OU: $($group.ou)" -ForegroundColor Gray
                        Write-Host "  Description: $($group.description)" -ForegroundColor Gray
                        
                        $results.ADGroups += @{
                            GroupName = $group.name
                            Action = "DryRun"
                            Message = "Would create group"
                            Success = $true
                        }
                        $results.TotalSuccess++
                    } else {
                        # Check if group exists
                        $existingGroup = Get-ADGroup -Filter "Name -eq '$($group.name)'" -ErrorAction SilentlyContinue
                        
                        if ($existingGroup) {
                            Write-Host "  ✓ Group already exists" -ForegroundColor Green
                            $results.ADGroups += @{
                                GroupName = $group.name
                                Action = "Skipped"
                                Message = "Group already exists"
                                Success = $true
                            }
                            $results.TotalSuccess++
                        } else {
                            # Create the group
                            New-ADGroup -Name $group.name `
                                       -GroupScope Global `
                                       -GroupCategory Security `
                                       -Path $group.ou `
                                       -Description $group.description `
                                       -ErrorAction Stop
                            
                            Write-Host "  ✓ Group created successfully" -ForegroundColor Green
                            $results.ADGroups += @{
                                GroupName = $group.name
                                Action = "Created"
                                Message = "Group created successfully"
                                Success = $true
                            }
                            $results.TotalSuccess++
                            
                            # Wait for AD replication
                            Start-Sleep -Seconds 2
                        }
                    }
                } catch {
                    Write-Host "  ✗ Failed to create group: $($_.Exception.Message)" -ForegroundColor Red
                    $results.ADGroups += @{
                        GroupName = $group.name
                        Action = "Failed"
                        Message = $_.Exception.Message
                        Success = $false
                    }
                    $results.TotalFailed++
                }
            }
        }
    }
}

# ============================================================================
# AZURE AD OPERATIONS
# ============================================================================
if ($OperationType -eq 'all' -or $OperationType -eq 'azureADGroupsOnly') {
    Write-Host "`n=== AZURE AD OPERATIONS ===" -ForegroundColor Cyan
    
    if ($envConfig.azureADGroups.Count -eq 0) {
        Write-Host "No Azure AD groups configured for this environment" -ForegroundColor Yellow
    } else {
        # Check for Azure AD module
        if (-not (Get-Module -ListAvailable -Name AzureAD)) {
            Write-Warning "AzureAD module not installed. Install with: Install-Module AzureAD"
            $results.TotalFailed += $envConfig.azureADGroups.Count
        } else {
            try {
                Import-Module AzureAD -ErrorAction Stop
                
                if (-not $DryRun) {
                    # Connect to Azure AD
                    Write-Host "Connecting to Azure AD (Tenant: $AzureTenantId)..." -ForegroundColor Yellow
                    Connect-AzureAD -TenantId $AzureTenantId -ErrorAction Stop | Out-Null
                    Write-Host "✓ Connected to Azure AD" -ForegroundColor Green
                }
                
                foreach ($group in $envConfig.azureADGroups) {
                    Write-Host "`nProcessing Azure AD Group: $($group.name)" -ForegroundColor Yellow
                    
                    try {
                        if ($DryRun) {
                            Write-Host "[DRY RUN] Would create Azure AD group: $($group.name)" -ForegroundColor Cyan
                            Write-Host "  Description: $($group.description)" -ForegroundColor Gray
                            
                            $results.AzureADGroups += @{
                                GroupName = $group.name
                                Action = "DryRun"
                                Message = "Would create group"
                                Success = $true
                            }
                            $results.TotalSuccess++
                        } else {
                            # Check if group exists
                            $existingGroup = Get-AzureADGroup -Filter "DisplayName eq '$($group.name)'" -ErrorAction SilentlyContinue
                            
                            if ($existingGroup) {
                                Write-Host "  ✓ Group already exists (ObjectId: $($existingGroup.ObjectId))" -ForegroundColor Green
                                $results.AzureADGroups += @{
                                    GroupName = $group.name
                                    Action = "Skipped"
                                    Message = "Group already exists"
                                    ObjectId = $existingGroup.ObjectId
                                    Success = $true
                                }
                                $results.TotalSuccess++
                            } else {
                                # Create the group
                                $mailNickname = $group.name -replace '\s', ''
                                $newGroup = New-AzureADGroup -DisplayName $group.name `
                                                            -Description $group.description `
                                                            -MailEnabled $false `
                                                            -SecurityEnabled $true `
                                                            -MailNickname $mailNickname `
                                                            -ErrorAction Stop
                                
                                Write-Host "  ✓ Group created successfully (ObjectId: $($newGroup.ObjectId))" -ForegroundColor Green
                                $results.AzureADGroups += @{
                                    GroupName = $group.name
                                    Action = "Created"
                                    Message = "Group created successfully"
                                    ObjectId = $newGroup.ObjectId
                                    Success = $true
                                }
                                $results.TotalSuccess++
                            }
                        }
                    } catch {
                        Write-Host "  ✗ Failed to create group: $($_.Exception.Message)" -ForegroundColor Red
                        $results.AzureADGroups += @{
                            GroupName = $group.name
                            Action = "Failed"
                            Message = $_.Exception.Message
                            Success = $false
                        }
                        $results.TotalFailed++
                    }
                }
            } catch {
                Write-Error "Failed to connect to Azure AD: $($_.Exception.Message)"
                $results.TotalFailed += $envConfig.azureADGroups.Count
            }
        }
    }
}

# ============================================================================
# SQL SERVER OPERATIONS (On-Prem)
# ============================================================================
if ($OperationType -eq 'all' -or $OperationType -eq 'sqlPermissionsOnly') {
    Write-Host "`n=== SQL SERVER OPERATIONS ===" -ForegroundColor Cyan
    
    if ($envConfig.sqlServers.Count -eq 0) {
        Write-Host "No SQL servers configured for this environment" -ForegroundColor Yellow
    } else {
        foreach ($sqlServer in $envConfig.sqlServers) {
            Write-Host "`nProcessing SQL Server: $($sqlServer.instance)" -ForegroundColor Yellow
            
            # Check if SQL service is running
            $serverName = $sqlServer.instance.Split('.')[0]
            $serviceRunning = $false
            
            try {
                $service = Get-Service -Name MSSQLSERVER -ComputerName $serverName -ErrorAction SilentlyContinue
                $serviceRunning = ($service.Status -eq 'Running')
                
                if (-not $serviceRunning) {
                    Write-Warning "  SQL Server service not running on $serverName"
                }
            } catch {
                Write-Warning "  Cannot check service status on $serverName"
            }
            
            foreach ($groupName in $sqlServer.groups) {
                $adGroup = "DOMAIN\$groupName"
                Write-Host "  Processing group: $adGroup" -ForegroundColor Gray
                
                try {
                    if ($DryRun) {
                        Write-Host "  [DRY RUN] Would create login and assign roles: $($sqlServer.roles -join ', ')" -ForegroundColor Cyan
                        
                        $results.SQLServers += @{
                            Server = $sqlServer.instance
                            Group = $adGroup
                            Roles = $sqlServer.roles -join ', '
                            Action = "DryRun"
                            Success = $true
                        }
                        $results.TotalSuccess++
                    } elseif (-not $serviceRunning) {
                        Write-Host "  ⊘ Skipped - SQL service not running" -ForegroundColor Yellow
                        $results.SQLServers += @{
                            Server = $sqlServer.instance
                            Group = $adGroup
                            Action = "Skipped"
                            Message = "SQL service not running"
                            Success = $false
                        }
                        $results.TotalFailed++
                    } else {
                        # Create SQL connection
                        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
                        $sqlConnection.ConnectionString = "Server=$($sqlServer.instance);Integrated Security=True;TrustServerCertificate=True"
                        $sqlConnection.Open()
                        
                        $sqlCommand = $sqlConnection.CreateCommand()
                        
                        # Create login if not exists
                        $sqlCommand.CommandText = "IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = '$adGroup') CREATE LOGIN [$adGroup] FROM WINDOWS"
                        $sqlCommand.ExecuteNonQuery() | Out-Null
                        
                        # Assign roles
                        foreach ($role in $sqlServer.roles) {
                            $sqlCommand.CommandText = "ALTER SERVER ROLE $role ADD MEMBER [$adGroup]"
                            $sqlCommand.ExecuteNonQuery() | Out-Null
                            Write-Host "    ✓ Assigned role: $role" -ForegroundColor Green
                        }
                        
                        $sqlConnection.Close()
                        
                        Write-Host "  ✓ Permissions applied successfully" -ForegroundColor Green
                        $results.SQLServers += @{
                            Server = $sqlServer.instance
                            Group = $adGroup
                            Roles = $sqlServer.roles -join ', '
                            Action = "Success"
                            Success = $true
                        }
                        $results.TotalSuccess++
                    }
                } catch {
                    Write-Host "  ✗ Failed to apply permissions: $($_.Exception.Message)" -ForegroundColor Red
                    $results.SQLServers += @{
                        Server = $sqlServer.instance
                        Group = $adGroup
                        Action = "Failed"
                        Message = $_.Exception.Message
                        Success = $false
                    }
                    $results.TotalFailed++
                }
            }
        }
    }
}

# ============================================================================
# AZURE SQL OPERATIONS
# ============================================================================
if ($OperationType -eq 'all' -or $OperationType -eq 'azureSQLPermissionsOnly') {
    Write-Host "`n=== AZURE SQL OPERATIONS ===" -ForegroundColor Cyan
    
    if ($envConfig.azureSQLServers.Count -eq 0) {
        Write-Host "No Azure SQL servers configured for this environment" -ForegroundColor Yellow
    } else {
        # Check for required modules
        if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
            Write-Warning "Az.Accounts module not installed. Install with: Install-Module Az.Accounts"
            $results.TotalFailed += $envConfig.azureSQLServers.Count
        } elseif (-not (Get-Module -ListAvailable -Name dbatools)) {
            Write-Warning "dbatools module not installed. Install with: Install-Module dbatools"
            $results.TotalFailed += $envConfig.azureSQLServers.Count
        } else {
            try {
                Import-Module Az.Accounts -ErrorAction Stop
                Import-Module dbatools -ErrorAction Stop
                
                if (-not $DryRun) {
                    # Connect to Azure
                    Write-Host "Connecting to Azure..." -ForegroundColor Yellow
                    Connect-AzAccount -TenantId $AzureTenantId -ErrorAction Stop | Out-Null
                    Write-Host "✓ Connected to Azure" -ForegroundColor Green
                }
                
                foreach ($azureSql in $envConfig.azureSQLServers) {
                    Write-Host "`nProcessing Azure SQL Server: $($azureSql.instance)" -ForegroundColor Yellow
                    
                    if ($DryRun) {
                        Write-Host "[DRY RUN] Would configure Azure SQL permissions" -ForegroundColor Cyan
                        Write-Host "  Groups: $($azureSql.groups -join ', ')" -ForegroundColor Gray
                        Write-Host "  Databases: $($azureSql.databases -join ', ')" -ForegroundColor Gray
                        Write-Host "  Roles: $($azureSql.roles -join ', ')" -ForegroundColor Gray
                        
                        $results.AzureSQLServers += @{
                            Server = $azureSql.instance
                            Action = "DryRun"
                            Success = $true
                        }
                        $results.TotalSuccess++
                    } else {
                        # Set subscription context
                        Set-AzContext -SubscriptionId $azureSql.subscriptionId | Out-Null
                        
                        # Get access token
                        $azureToken = Get-AzAccessToken -ResourceUrl "https://database.windows.net"
                        
                        # Connect to Azure SQL
                        $sqlConnection = Connect-DbaInstance -SqlInstance $azureSql.instance -AccessToken $azureToken
                        
                        foreach ($groupName in $azureSql.groups) {
                            Write-Host "  Processing group: $groupName" -ForegroundColor Gray
                            
                            try {
                                # Create login from external provider
                                $createLoginQuery = "IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = '$groupName') CREATE LOGIN [$groupName] FROM EXTERNAL PROVIDER"
                                Invoke-DbaQuery -SqlInstance $sqlConnection -Query $createLoginQuery -ErrorAction Stop
                                Write-Host "    ✓ Login created/verified" -ForegroundColor Green
                                
                                # Get databases to configure
                                $databasesToConfig = @()
                                if ($azureSql.databases -contains "all") {
                                    $databasesToConfig = (Get-DbaDatabase -SqlInstance $sqlConnection -ExcludeSystem).Name
                                } else {
                                    $databasesToConfig = $azureSql.databases
                                }
                                
                                # Apply permissions to each database
                                foreach ($dbName in $databasesToConfig) {
                                    $dbConnection = Connect-DbaInstance -SqlInstance $azureSql.instance -Database $dbName -AccessToken $azureToken
                                    
                                    $dbQuery = @"
USE [$dbName];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '$groupName')
BEGIN
    CREATE USER [$groupName] FOR LOGIN [$groupName];
END
"@
                                    foreach ($role in $azureSql.roles) {
                                        $dbQuery += "`nALTER ROLE $role ADD MEMBER [$groupName];"
                                    }
                                    
                                    Invoke-DbaQuery -SqlInstance $dbConnection -Query $dbQuery -ErrorAction Stop
                                    Write-Host "    ✓ Permissions applied to database: $dbName" -ForegroundColor Green
                                }
                                
                                $results.AzureSQLServers += @{
                                    Server = $azureSql.instance
                                    Group = $groupName
                                    Databases = $databasesToConfig.Count
                                    Roles = $azureSql.roles -join ', '
                                    Action = "Success"
                                    Success = $true
                                }
                                $results.TotalSuccess++
                                
                            } catch {
                                Write-Host "    ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
                                $results.AzureSQLServers += @{
                                    Server = $azureSql.instance
                                    Group = $groupName
                                    Action = "Failed"
                                    Message = $_.Exception.Message
                                    Success = $false
                                }
                                $results.TotalFailed++
                            }
                        }
                    }
                }
            } catch {
                Write-Error "Failed to connect to Azure: $($_.Exception.Message)"
                $results.TotalFailed += $envConfig.azureSQLServers.Count
            }
        }
    }
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================
$results.EndTime = Get-Date
$results.Duration = $results.EndTime - $results.StartTime

Write-Host "`n=== FINAL SUMMARY ===" -ForegroundColor Cyan
Write-Host "Execution completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Duration: $($results.Duration.ToString('mm\:ss'))"
Write-Host "Environment: $Environment"
Write-Host "Operation Type: $OperationType"
Write-Host "Dry Run: $DryRun"
Write-Host ""

Write-Host "Results:" -ForegroundColor Yellow
Write-Host "  Total Successful: $($results.TotalSuccess)" -ForegroundColor Green
Write-Host "  Total Failed: $($results.TotalFailed)" -ForegroundColor $(if ($results.TotalFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($results.ADGroups.Count -gt 0) {
    Write-Host "AD Groups:" -ForegroundColor Yellow
    $results.ADGroups | ForEach-Object {
        $color = if ($_.Success) { "Green" } else { "Red" }
        Write-Host "  $($_.GroupName): $($_.Action)" -ForegroundColor $color
    }
    Write-Host ""
}

if ($results.AzureADGroups.Count -gt 0) {
    Write-Host "Azure AD Groups:" -ForegroundColor Yellow
    $results.AzureADGroups | ForEach-Object {
        $color = if ($_.Success) { "Green" } else { "Red" }
        Write-Host "  $($_.GroupName): $($_.Action)" -ForegroundColor $color
    }
    Write-Host ""
}

if ($results.SQLServers.Count -gt 0) {
    Write-Host "SQL Servers:" -ForegroundColor Yellow
    $results.SQLServers | ForEach-Object {
        $color = if ($_.Success) { "Green" } else { "Red" }
        Write-Host "  $($_.Server) - $($_.Group): $($_.Action)" -ForegroundColor $color
    }
    Write-Host ""
}

if ($results.AzureSQLServers.Count -gt 0) {
    Write-Host "Azure SQL Servers:" -ForegroundColor Yellow
    $results.AzureSQLServers | ForEach-Object {
        $color = if ($_.Success) { "Green" } else { "Red" }
        Write-Host "  $($_.Server) - $($_.Group): $($_.Action)" -ForegroundColor $color
    }
    Write-Host ""
}

# Export results to JSON
$resultsFile = Join-Path $OutputPath "sql-permissions-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$results | ConvertTo-Json -Depth 10 | Out-File $resultsFile
Write-Host "Results exported to: $resultsFile" -ForegroundColor Cyan

# Set ADO pipeline variables
Write-Host "##vso[task.setvariable variable=SQLPermissions.TotalSuccess]$($results.TotalSuccess)"
Write-Host "##vso[task.setvariable variable=SQLPermissions.TotalFailed]$($results.TotalFailed)"
Write-Host "##vso[task.setvariable variable=SQLPermissions.Environment]$Environment"
Write-Host "##vso[task.setvariable variable=SQLPermissions.OperationType]$OperationType"

if ($results.TotalFailed -gt 0) {
    Write-Host "`nOperation completed with $($results.TotalFailed) failures" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`nOperation completed successfully!" -ForegroundColor Green
    exit 0
}
