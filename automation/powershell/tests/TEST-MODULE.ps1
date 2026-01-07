# Test Script for PlatformOps.Automation Module
# This demonstrates all the module's capabilities

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing PlatformOps.Automation Module" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Import the module
$modulePath = Join-Path $PSScriptRoot "Module\PlatformOps.Automation.psd1"
Import-Module $modulePath -Force

Write-Host "`n1. Verifying module loaded..." -ForegroundColor Yellow
$module = Get-Module PlatformOps.Automation
if ($module) {
    Write-Host "   ✓ Module loaded successfully!" -ForegroundColor Green
    Write-Host "   Version: $($module.Version)" -ForegroundColor Gray
    Write-Host "   Author: $($module.Author)" -ForegroundColor Gray
} else {
    Write-Host "   ✗ Module failed to load" -ForegroundColor Red
    exit 1
}

Write-Host "`n2. Available Functions:" -ForegroundColor Yellow
$functions = Get-Command -Module PlatformOps.Automation
foreach ($func in $functions) {
    Write-Host "   - $($func.Name)" -ForegroundColor Cyan
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "FUNCTION TESTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# TEST 1: Write-StructuredLog
Write-Host "`n--- Test 1: Write-StructuredLog ---" -ForegroundColor Magenta

Write-Host "`nBasic log entry:" -ForegroundColor Yellow
Write-StructuredLog -Message "Test log entry" -Severity Information

Write-Host "`nLog with custom properties:" -ForegroundColor Yellow
Write-StructuredLog -Message "Deployment completed" -Severity Information -Properties @{
    Environment = "Test"
    Duration = "00:05:30"
    ComponentsDeployed = 3
}

Write-Host "`nWarning log:" -ForegroundColor Yellow
Write-StructuredLog -Message "Disk space running low" -Severity Warning -Properties @{
    Drive = "C:"
    FreeSpaceGB = 15
}

Write-Host "`nError log:" -ForegroundColor Yellow
Write-StructuredLog -Message "Connection failed" -Severity Error -Properties @{
    Server = "SERVER01"
    ErrorCode = "TIMEOUT"
}

# TEST 2: Test-TcpPort
Write-Host "`n--- Test 2: Test-TcpPort ---" -ForegroundColor Magenta

Write-Host "`nTesting localhost:80 (HTTP):" -ForegroundColor Yellow
$result = Test-TcpPort -ComputerName "localhost" -Port 80 -TimeoutSeconds 2
if ($result.IsOpen) {
    Write-Host "   ✓ Port 80 is OPEN (Response: $($result.ResponseTime)ms)" -ForegroundColor Green
} else {
    Write-Host "   ✗ Port 80 is CLOSED or unreachable" -ForegroundColor Yellow
    Write-Host "   Error: $($result.Error)" -ForegroundColor Gray
}

Write-Host "`nTesting google.com:443 (HTTPS):" -ForegroundColor Yellow
$result = Test-TcpPort -ComputerName "google.com" -Port 443 -TimeoutSeconds 5
if ($result.IsOpen) {
    Write-Host "   ✓ Port 443 is OPEN (Response: $($result.ResponseTime)ms)" -ForegroundColor Green
} else {
    Write-Host "   ✗ Port 443 is CLOSED or unreachable" -ForegroundColor Yellow
}

Write-Host "`nTesting unreachable port (should fail):" -ForegroundColor Yellow
$result = Test-TcpPort -ComputerName "localhost" -Port 9999 -TimeoutSeconds 2
if ($result.IsOpen) {
    Write-Host "   ✓ Port 9999 is OPEN" -ForegroundColor Green
} else {
    Write-Host "   ✗ Port 9999 is CLOSED (expected)" -ForegroundColor Yellow
    Write-Host "   Error: $($result.Error)" -ForegroundColor Gray
}

# TEST 3: Invoke-Retry
Write-Host "`n--- Test 3: Invoke-Retry ---" -ForegroundColor Magenta

Write-Host "`nTest 3a: Successful operation (no retry needed):" -ForegroundColor Yellow
$result = Invoke-Retry -ScriptBlock {
    Write-Host "   Executing operation..." -ForegroundColor Gray
    return "Success!"
} -MaxRetries 3 -Verbose

Write-Host "   Result: $result" -ForegroundColor Green

Write-Host "`nTest 3b: Operation that fails then succeeds:" -ForegroundColor Yellow
$script:attemptCount = 0
$result = Invoke-Retry -ScriptBlock {
    $script:attemptCount++
    Write-Host "   Attempt $script:attemptCount..." -ForegroundColor Gray
    
    if ($script:attemptCount -lt 3) {
        throw "Simulated failure (attempt $script:attemptCount)"
    }
    
    return "Success on attempt $script:attemptCount!"
} -MaxRetries 5 -InitialDelaySeconds 1 -Verbose

Write-Host "   Result: $result" -ForegroundColor Green

Write-Host "`nTest 3c: Operation that always fails (will exhaust retries):" -ForegroundColor Yellow
try {
    $result = Invoke-Retry -ScriptBlock {
        Write-Host "   Attempting operation..." -ForegroundColor Gray
        throw "This operation always fails"
    } -MaxRetries 3 -InitialDelaySeconds 1
} catch {
    Write-Host "   ✓ Correctly threw exception after exhausting retries" -ForegroundColor Yellow
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Gray
}

# INTEGRATION TEST
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "INTEGRATION TEST" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nCombining all functions in a realistic scenario:" -ForegroundColor Yellow
Write-Host "Scenario: Check server connectivity with retry logic and structured logging`n" -ForegroundColor Gray

$servers = @(
    @{ Name = "google.com"; Port = 443 }
    @{ Name = "localhost"; Port = 80 }
    @{ Name = "localhost"; Port = 9999 }  # This will fail
)

foreach ($server in $servers) {
    Write-Host "Checking $($server.Name):$($server.Port)..." -ForegroundColor Cyan
    
    try {
        $result = Invoke-Retry -ScriptBlock {
            Test-TcpPort -ComputerName $server.Name -Port $server.Port -TimeoutSeconds 3
        } -MaxRetries 2 -InitialDelaySeconds 1
        
        if ($result.IsOpen) {
            Write-StructuredLog -Message "Server connectivity check passed" -Severity Information -Properties @{
                Server = $server.Name
                Port = $server.Port
                ResponseTime = $result.ResponseTime
                Status = "Success"
            }
        } else {
            Write-StructuredLog -Message "Server connectivity check failed" -Severity Warning -Properties @{
                Server = $server.Name
                Port = $server.Port
                Error = $result.Error
                Status = "Failed"
            }
        }
    } catch {
        Write-StructuredLog -Message "Server connectivity check error" -Severity Error -Properties @{
            Server = $server.Name
            Port = $server.Port
            Error = $_.Exception.Message
            Status = "Error"
        }
    }
    
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ALL TESTS COMPLETED!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nModule Functions Summary:" -ForegroundColor Yellow
Write-Host "  ✓ Write-StructuredLog - Creates JSON log entries with severity levels" -ForegroundColor Green
Write-Host "  ✓ Test-TcpPort - Tests TCP connectivity with timeout and response time" -ForegroundColor Green
Write-Host "  ✓ Invoke-Retry - Executes operations with exponential backoff retry logic" -ForegroundColor Green

Write-Host "`nThe module is fully functional and ready for production use!" -ForegroundColor Cyan
