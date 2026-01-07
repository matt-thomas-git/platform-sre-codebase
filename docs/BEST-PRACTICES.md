# Best Practices & Coding Standards

## PowerShell Coding Standards

### 1. **Script Structure**

Every production script follows this structure:

```powershell
<#
.SYNOPSIS
    Brief description of what the script does

.DESCRIPTION
    Detailed description including:
    - What problem it solves
    - How it works
    - Prerequisites
    
.PARAMETER ParameterName
    Description of each parameter

.EXAMPLE
    .\Script-Name.ps1 -Parameter Value
    Description of what this example does

.NOTES
    Author: Name
    Date: YYYY-MM-DD
    Version: X.Y
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$false)]
    [string]$Parameter1,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Set error handling
$ErrorActionPreference = "Stop"

# Main script logic here
```

### 2. **Naming Conventions**

- **Scripts**: `Verb-Noun-Description.ps1` (e.g., `Get-SqlHealth.ps1`)
- **Functions**: `Verb-Noun` (e.g., `Invoke-Retry`)
- **Variables**: `$camelCase` for local, `$PascalCase` for parameters
- **Constants**: `$UPPER_CASE` (e.g., `$MAX_RETRIES`)

```powershell
# Good
$serverName = "PRODSQL01"
$MaxRetryCount = 3
$TIMEOUT_SECONDS = 30

# Avoid
$s = "PRODSQL01"
$max = 3
```

### 3. **Error Handling**

Always use try-catch blocks for operations that might fail:

```powershell
try {
    $result = Invoke-SqlCmd -Query $query -ServerInstance $server
    Write-Host "✓ Query executed successfully" -ForegroundColor Green
}
catch {
    Write-Host "✗ Query failed: $_" -ForegroundColor Red
    Write-Host "Server: $server" -ForegroundColor Yellow
    Write-Host "Query: $query" -ForegroundColor Yellow
    
    # Log error
    $errorDetails = @{
        Server = $server
        Query = $query
        Error = $_.Exception.Message
        Timestamp = Get-Date
    }
    $errorDetails | Export-Csv -Path "errors.csv" -Append -NoTypeInformation
    
    # Decide whether to continue or throw
    if ($ContinueOnError) {
        continue
    } else {
        throw
    }
}
```

### 4. **Parameter Validation**

Validate inputs early:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServerName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Dev", "UAT", "Prod")]
    [string]$Environment = "Dev",
    
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 10)]
    [int]$RetryCount = 3,
    
    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path $_})]
    [string]$ConfigPath
)

# Additional validation
if ($Environment -eq "Prod" -and !$Confirm) {
    throw "Production changes require -Confirm switch"
}
```

### 5. **Logging Best Practices**

Implement structured logging:

```powershell
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    $color = switch ($Level) {
        "ERROR"   { "Red" }
        "WARN"    { "Yellow" }
        "SUCCESS" { "Green" }
        default   { "Cyan" }
    }
    Write-Host $logMessage -ForegroundColor $color
    
    # File output
    $logMessage | Out-File -FilePath "script.log" -Append
}

# Usage
Write-Log "Starting SQL permissions update" -Level "INFO"
Write-Log "Connected to server: $serverName" -Level "SUCCESS"
Write-Log "Permission already exists, skipping" -Level "WARN"
Write-Log "Failed to connect: $($_.Exception.Message)" -Level "ERROR"
```

## SQL Automation Best Practices

### 1. **Connection Management**

```powershell
# Use connection pooling
$connectionString = "Server=$serverName;Database=master;Integrated Security=True;Connection Timeout=30;"

# Always close connections
try {
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()
    
    # Execute queries
    
} finally {
    if ($connection.State -eq 'Open') {
        $connection.Close()
    }
}
```

### 2. **SQL Injection Prevention**

```powershell
# Bad - vulnerable to SQL injection
$query = "SELECT * FROM Users WHERE Username = '$username'"

# Good - use parameterized queries
$query = "SELECT * FROM Users WHERE Username = @Username"
$cmd = New-Object System.Data.SqlClient.SqlCommand($query, $connection)
$cmd.Parameters.AddWithValue("@Username", $username)
```

### 3. **Transaction Management**

```powershell
$connection.BeginTransaction()
try {
    # Execute multiple commands
    Invoke-SqlCmd -Query $query1 -Connection $connection
    Invoke-SqlCmd -Query $query2 -Connection $connection
    
    $connection.CommitTransaction()
    Write-Log "Transaction committed successfully" -Level "SUCCESS"
}
catch {
    $connection.RollbackTransaction()
    Write-Log "Transaction rolled back: $_" -Level "ERROR"
    throw
}
```

## Azure Automation Best Practices

### 1. **Authentication**

```powershell
# Use managed identity when possible
Connect-AzAccount -Identity

# For service principals, use secure credential storage
$credential = Get-AutomationPSCredential -Name 'AzureServicePrincipal'
Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $tenantId
```

### 2. **Resource Tagging**

```powershell
# Always tag resources for governance
$tags = @{
    Environment = "Production"
    Owner = "Platform-Team"
    CostCenter = "IT-Infrastructure"
    ManagedBy = "Automation"
    CreatedDate = (Get-Date -Format "yyyy-MM-dd")
}

Set-AzResource -ResourceId $resourceId -Tag $tags -Force
```

### 3. **Idempotent Operations**

```powershell
# Check before creating
$lb = Get-AzLoadBalancer -Name $lbName -ResourceGroupName $rgName -ErrorAction SilentlyContinue

if ($lb) {
    Write-Log "Load balancer already exists, checking configuration..." -Level "INFO"
    # Update if needed
} else {
    Write-Log "Creating new load balancer..." -Level "INFO"
    $lb = New-AzLoadBalancer -Name $lbName -ResourceGroupName $rgName -Location $location
}
```

## CI/CD Pipeline Best Practices

### 1. **Pipeline Structure**

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - automation/*

variables:
  - group: production-secrets
  - name: environment
    value: 'production'

stages:
  - stage: Validate
    jobs:
      - job: ValidateScripts
        steps:
          - task: PowerShell@2
            displayName: 'Run PSScriptAnalyzer'
            inputs:
              targetType: 'inline'
              script: |
                Invoke-ScriptAnalyzer -Path . -Recurse
  
  - stage: Deploy
    dependsOn: Validate
    jobs:
      - deployment: DeployAutomation
        environment: 'production'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: PowerShell@2
                  displayName: 'Execute Automation'
```

### 2. **Secret Management**

```powershell
# Never hardcode secrets
# Bad
$password = "MyPassword123"

# Good - use Azure Key Vault
$secret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $secretName
$password = $secret.SecretValueText

# Or use pipeline variables
$password = $env:AZURE_PASSWORD
```

### 3. **Approval Gates**

```yaml
- stage: ProductionDeploy
  dependsOn: UATDeploy
  jobs:
    - deployment: DeployToProduction
      environment: 'production'  # Requires manual approval
      strategy:
        runOnce:
          deploy:
            steps:
              - script: echo Deploying to production
```

## Testing Best Practices

### 1. **Unit Testing with Pester**

```powershell
Describe "Get-SqlHealth" {
    Context "When server is reachable" {
        It "Should return health status" {
            $result = Get-SqlHealth -ServerName "TESTSQL01"
            $result.Status | Should -Be "Healthy"
        }
    }
    
    Context "When server is unreachable" {
        It "Should throw an error" {
            { Get-SqlHealth -ServerName "INVALID" } | Should -Throw
        }
    }
}
```

### 2. **Integration Testing**

```powershell
# Test against non-production environment first
if ($Environment -ne "Prod") {
    Write-Log "Running in test mode against $Environment" -Level "INFO"
    $testServer = "DEVSQL01"
} else {
    if (!$Confirm) {
        throw "Production deployment requires -Confirm switch"
    }
    $testServer = "PRODSQL01"
}
```

### 3. **WhatIf Implementation**

```powershell
function Set-SqlPermission {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ServerName,
        [string]$Username,
        [string]$Permission
    )
    
    if ($PSCmdlet.ShouldProcess($ServerName, "Grant $Permission to $Username")) {
        # Actual implementation
        Invoke-SqlCmd -Query "GRANT $Permission TO [$Username]" -ServerInstance $ServerName
        Write-Log "Granted $Permission to $Username on $ServerName" -Level "SUCCESS"
    } else {
        Write-Log "WOULD: Grant $Permission to $Username on $ServerName" -Level "INFO"
    }
}

# Usage
Set-SqlPermission -ServerName "PRODSQL01" -Username "AppUser" -Permission "db_datareader" -WhatIf
```

## Performance Optimization

### 1. **Parallel Processing**

```powershell
# Process multiple servers in parallel
$servers = @("SQL01", "SQL02", "SQL03", "SQL04")

$servers | ForEach-Object -Parallel {
    $server = $_
    try {
        $result = Invoke-SqlCmd -Query "SELECT @@VERSION" -ServerInstance $server
        Write-Host "✓ $server is responsive" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ $server failed: $_" -ForegroundColor Red
    }
} -ThrottleLimit 4
```

### 2. **Efficient Data Handling**

```powershell
# Bad - loads entire result set into memory
$allData = Invoke-SqlCmd -Query "SELECT * FROM LargeTable"

# Good - stream results
$reader = Invoke-SqlCmd -Query "SELECT * FROM LargeTable" -As DataReader
while ($reader.Read()) {
    # Process one row at a time
    Process-Row -Data $reader
}
```

### 3. **Caching**

```powershell
# Cache Azure context to avoid repeated authentication
$script:azContext = $null

function Get-CachedAzContext {
    if ($null -eq $script:azContext) {
        $script:azContext = Get-AzContext
    }
    return $script:azContext
}
```

## Documentation Standards

### 1. **Inline Comments**

```powershell
# Good comments explain WHY, not WHAT
# Bad
$retryCount = 3  # Set retry count to 3

# Good
$retryCount = 3  # Azure API occasionally returns transient errors; 3 retries with backoff handles 99% of cases
```

### 2. **README Files**

Every automation folder should have a README with:
- Purpose and scope
- Prerequisites
- Usage examples
- Configuration details
- Troubleshooting guide

### 3. **Change Documentation**

```powershell
<#
.NOTES
    Version History:
    1.0 - 2024-01-15 - Initial version
    1.1 - 2024-02-20 - Added retry logic for transient failures
    1.2 - 2024-03-10 - Implemented parallel processing for better performance
    2.0 - 2024-04-05 - Complete rewrite using Azure PowerShell modules
#>
```

## Security Best Practices

### 1. **Least Privilege**

```powershell
# Request only the permissions needed
$role = "Reader"  # Not "Owner" unless absolutely necessary
New-AzRoleAssignment -ObjectId $objectId -RoleDefinitionName $role -Scope $scope
```

### 2. **Credential Handling**

```powershell
# Never log credentials
Write-Log "Connecting to $serverName as $username" -Level "INFO"
# Don't log: Write-Log "Password: $password"

# Use SecureString
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)
```

### 3. **Audit Logging**

```powershell
# Log all significant actions
$auditEntry = [PSCustomObject]@{
    Timestamp = Get-Date
    User = $env:USERNAME
    Action = "GrantPermission"
    Target = "$serverName.$databaseName"
    Details = "Granted $permission to $username"
    Success = $true
}
$auditEntry | Export-Csv -Path "audit.csv" -Append -NoTypeInformation
```

## Code Review Checklist

Before committing code, verify:

- [ ] Script has proper synopsis and description
- [ ] All parameters are documented
- [ ] Error handling is comprehensive
- [ ] Logging is implemented
- [ ] WhatIf/Confirm support for destructive operations
- [ ] No hardcoded credentials or secrets
- [ ] No company-specific information
- [ ] Code follows naming conventions
- [ ] Comments explain complex logic
- [ ] Examples are provided
- [ ] Script has been tested in non-production
- [ ] PSScriptAnalyzer shows no errors
