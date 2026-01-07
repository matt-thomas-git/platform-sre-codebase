# Platform Automation

Reusable automation components for Platform SRE operations, including PowerShell modules and Python utilities.

## Overview

This folder contains two types of automation:

1. **Reusable Module** (`powershell/Module/`) - Core utility functions for building automation
2. **Production Scripts** (`powershell/scripts/examples/`) - Complete, ready-to-use automation solutions
3. **Python Utilities** (`python/`) - Cross-platform health checking tools

## Structure

```
automation/
├── README.md (this file)
├── powershell/
│   ├── Module/                             # REUSABLE MODULE
│   │   ├── PlatformOps.Automation.psd1    # Module manifest
│   │   ├── PlatformOps.Automation.psm1    # Module loader
│   │   └── Public/                         # 3 exported functions
│   │       ├── Invoke-Retry.ps1           # Retry logic with backoff
│   │       ├── Write-StructuredLog.ps1    # JSON structured logging
│   │       └── Test-TcpPort.ps1           # TCP connectivity testing
│   ├── scripts/
│   │   ├── examples/                       # PRODUCTION SCRIPTS
│   │   │   ├── README.md                  # Detailed script documentation
│   │   │   ├── Invoke-LogCleanup.ps1      # Multi-service log cleanup
│   │   │   ├── Set-AzureVmTagsFromPolicy.ps1  # Azure VM tagging
│   │   │   └── Get-SqlHealth.ps1          # SQL Server health monitoring
│   │   └── migration/                      # Migration utilities
│   ├── tests/
│   │   └── PlatformOps.Automation.Tests.ps1
│   └── TEST-MODULE.ps1                     # Module test/demo script
└── python/
    ├── health_probe.py                     # HTTP/HTTPS health checker
    ├── requirements.txt                    # Python dependencies
    └── endpoints-example.json              # Example config
```

### Key Distinction

**Module Functions vs. Production Scripts:**

| Type | Purpose | How to Use | Example |
|------|---------|------------|---------|
| **Module Functions** | Building blocks for automation | Import module, call functions | `Import-Module ...\Module\PlatformOps.Automation.psd1`<br>`Invoke-Retry { code }` |
| **Production Scripts** | Complete solutions for specific tasks | Run directly or schedule | `.\scripts\examples\Get-SqlHealth.ps1 -ServerInstance "SQL01"` |

**The scripts can USE the module functions** to enhance their capabilities (retry logic, structured logging, etc.)

## PowerShell Module: PlatformOps.Automation

A production-grade PowerShell module providing common automation functions for infrastructure management.

### Installation

```powershell
# Import the module
Import-Module .\automation\powershell\Module\PlatformOps.Automation.psd1

# Verify module loaded
Get-Module PlatformOps.Automation

# List available functions
Get-Command -Module PlatformOps.Automation
```

### Available Functions

#### Invoke-Retry
Executes operations with retry logic and exponential backoff.

```powershell
# Retry an API call
Invoke-Retry -ScriptBlock {
    Invoke-RestMethod -Uri "https://api.example.com/data" -Method Get
} -MaxRetries 5

# Retry with custom backoff
Invoke-Retry -ScriptBlock {
    Test-Connection -ComputerName "SERVER01" -Count 1 -ErrorAction Stop
} -MaxRetries 3 -InitialDelaySeconds 5 -MaxDelaySeconds 30
```

**Features:**
- Exponential backoff
- Configurable retry attempts
- Detailed verbose logging
- Error propagation

#### Write-StructuredLog
Creates structured JSON log entries for centralized logging systems.

```powershell
# Log with custom properties
Write-StructuredLog -Message "Deployment completed" -Severity Information -Properties @{
    Environment = "Production"
    Duration = "00:15:30"
    ComponentsDeployed = 5
}

# Log to file
Write-StructuredLog -Message "Error occurred" -Severity Error -Properties @{
    ErrorCode = "E001"
    Component = "Database"
} -LogPath "C:\Logs\automation.log"
```

**Features:**
- JSON formatted output
- Severity levels (Information, Warning, Error, Critical)
- Custom properties support
- File and console output
- Color-coded console display

#### Test-TcpPort
Tests TCP port connectivity with timeout and response time measurement.

```powershell
# Test single port
Test-TcpPort -ComputerName "webserver01" -Port 443

# Test with custom timeout
Test-TcpPort -ComputerName "sqlserver01" -Port 1433 -TimeoutSeconds 10

# Test multiple servers
@("SERVER01", "SERVER02", "SERVER03") | ForEach-Object {
    Test-TcpPort -ComputerName $_ -Port 3389
}
```

**Features:**
- Async connection testing
- Response time measurement
- Timeout configuration
- Pipeline support
- Detailed error reporting

### Usage Examples

#### Example 1: Robust API Call with Logging

```powershell
Import-Module .\automation\powershell\Module\PlatformOps.Automation.psd1

$result = Invoke-Retry -ScriptBlock {
    Write-StructuredLog -Message "Attempting API call" -Severity Information
    
    $response = Invoke-RestMethod -Uri "https://api.example.com/data" -Method Get
    
    Write-StructuredLog -Message "API call successful" -Severity Information -Properties @{
        RecordCount = $response.Count
    }
    
    return $response
} -MaxRetries 3

Write-Host "Retrieved $($result.Count) records"
```

#### Example 2: Pre-Deployment Connectivity Check

```powershell
$servers = @("WEB01", "WEB02", "APP01", "APP02", "SQL01")
$ports = @{
    "WEB" = 443
    "APP" = 8080
    "SQL" = 1433
}

foreach ($server in $servers) {
    $serverType = $server.Substring(0,3)
    $port = $ports[$serverType]
    
    $result = Test-TcpPort -ComputerName $server -Port $port
    
    Write-StructuredLog -Message "Connectivity check" -Severity $(if ($result.IsOpen) { "Information" } else { "Error" }) -Properties @{
        Server = $server
        Port = $port
        IsOpen = $result.IsOpen
        ResponseTime = $result.ResponseTime
    }
}
```

## Production Scripts

Complete, ready-to-use automation scripts for common Platform SRE tasks. These are **standalone scripts** that can be run directly, scheduled in pipelines, or used as scheduled tasks.

**Location:** `powershell/scripts/examples/`

### Available Scripts

#### 1. Invoke-LogCleanup.ps1
Multi-service log cleanup tool that auto-detects and cleans logs from SQL Server, IIS, and SSH Server.

```powershell
# Interactive mode with default retention
.\Invoke-LogCleanup.ps1

# Custom retention periods
.\Invoke-LogCleanup.ps1 -IISRetentionDays 60 -SSHRetentionDays 180

# Automated mode (no prompts)
.\Invoke-LogCleanup.ps1 -AutoConfirm
```

**Features:** Auto-detection, configurable retention, file size reporting, safe deletion with confirmation

#### 2. Set-AzureVmTagsFromPolicy.ps1
Azure VM tagging automation based on naming conventions across multiple subscriptions.

```powershell
# Interactive mode
.\Set-AzureVmTagsFromPolicy.ps1

# Preview mode (no changes)
.\Set-AzureVmTagsFromPolicy.ps1 -WhatIf

# Specific subscription
.\Set-AzureVmTagsFromPolicy.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"
```

**Features:** Multi-subscription support, pattern-based tagging, WhatIf support, CSV export

#### 3. Get-SqlHealth.ps1
Comprehensive SQL Server health monitoring including databases, TempDB, backups, jobs, and performance.

```powershell
# Basic health check
.\Get-SqlHealth.ps1 -ServerInstance "SQLSERVER01"

# Comprehensive check with backups and jobs
.\Get-SqlHealth.ps1 -ServerInstance "SQLSERVER01" -CheckBackups -CheckJobs

# Include performance monitoring
.\Get-SqlHealth.ps1 -ServerInstance "SQLSERVER01" -CheckPerformance
```

**Features:** Database status, TempDB config, disk space, backup status, job monitoring, blocking detection

### Using Scripts with Module Functions

The production scripts can leverage the module functions for enhanced capabilities:

```powershell
# Import the module first
Import-Module .\Module\PlatformOps.Automation.psd1

# Use retry logic with SQL health check
$healthData = Invoke-Retry -ScriptBlock {
    .\scripts\examples\Get-SqlHealth.ps1 -ServerInstance "SQLSERVER01"
} -MaxRetries 3

# Log the results
Write-StructuredLog -Message "SQL health check completed" -Severity Information -Properties @{
    Server = "SQLSERVER01"
    Status = "Success"
}
```

**See `scripts/examples/README.md` for detailed documentation on each script.**

## Python: Health Probe

HTTP/HTTPS health checking utility for monitoring web applications and APIs.

### Installation

```bash
# Install dependencies
pip install -r automation/python/requirements.txt

# Make executable (Linux/Mac)
chmod +x automation/python/health_probe.py
```

### Usage

#### Single URL Check

```bash
# Check single endpoint
python health_probe.py --url https://www.example.com

# With custom timeout
python health_probe.py --url https://api.example.com/health --timeout 15

# Disable SSL verification (for self-signed certs)
python health_probe.py --url https://internal-app.local --no-verify-ssl
```

#### Multiple Endpoints from Config

```bash
# Check multiple endpoints
python health_probe.py --config endpoints-example.json

# Save results to file
python health_probe.py --config endpoints-example.json --output results.json
```

#### Example Config File

```json
{
  "endpoints": [
    {
      "url": "https://www.example.com",
      "expected_status": 200
    },
    {
      "url": "https://api.example.com/health",
      "expected_status": 200
    }
  ]
}
```

### Features

- **HTTP/HTTPS Support**: Check any web endpoint
- **Response Time Measurement**: Track performance
- **Custom Status Codes**: Validate expected responses
- **SSL Verification**: Optional SSL certificate validation
- **JSON Output**: Machine-readable results
- **Exit Codes**: Integration with CI/CD pipelines
- **Batch Processing**: Check multiple endpoints from config

### Integration Examples

#### Azure DevOps Pipeline

```yaml
- task: UsePythonVersion@0
  inputs:
    versionSpec: '3.x'

- script: |
    pip install -r automation/python/requirements.txt
    python automation/python/health_probe.py --config endpoints.json --output health-results.json
  displayName: 'Run Health Checks'

- task: PublishBuildArtifacts@1
  inputs:
    PathtoPublish: 'health-results.json'
    ArtifactName: 'health-check-results'
```

#### PowerShell Integration

```powershell
# Run Python health probe from PowerShell
$result = python automation/python/health_probe.py --url "https://api.example.com" --output "health.json"

if ($LASTEXITCODE -eq 0) {
    Write-StructuredLog -Message "Health check passed" -Severity Information
} else {
    Write-StructuredLog -Message "Health check failed" -Severity Error
    exit 1
}
```

## Best Practices

### PowerShell Module

1. **Import Once**: Import the module at the start of your script
2. **Use Verbose**: Enable `-Verbose` for troubleshooting
3. **Error Handling**: Wrap function calls in try/catch blocks
4. **Structured Logging**: Use Write-StructuredLog for all operational logs
5. **Retry Logic**: Apply Invoke-Retry to transient operations

### Python Health Probe

1. **Timeout Configuration**: Set appropriate timeouts for your environment
2. **SSL Verification**: Only disable for trusted internal environments
3. **Config Files**: Use JSON configs for multiple endpoints
4. **CI/CD Integration**: Use exit codes for pipeline decisions
5. **Result Archiving**: Save JSON output for historical analysis

## Testing

### PowerShell Module Tests

```powershell
# Run Pester tests
Invoke-Pester -Path .\automation\powershell\tests\

# Test specific function
Import-Module .\automation\powershell\Module\PlatformOps.Automation.psd1
Test-TcpPort -ComputerName "localhost" -Port 80 -Verbose
```

### Python Health Probe Tests

```bash
# Test single URL
python health_probe.py --url https://www.google.com

# Test with example config
python health_probe.py --config endpoints-example.json
```

## Contributing

When adding new functions to the PowerShell module:

1. Create function file in `Public/` folder
2. Add comprehensive comment-based help
3. Include parameter validation
4. Add examples in help text
5. Update module manifest (psd1) FunctionsToExport
6. Create corresponding Pester tests

## Requirements

### PowerShell
- PowerShell 5.1 or later
- Windows PowerShell or PowerShell Core

### Python
- Python 3.7 or later
- requests library
- urllib3 library

## License

See LICENSE file in repository root.
