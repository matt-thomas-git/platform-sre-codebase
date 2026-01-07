function Test-TcpPort {
    <#
    .SYNOPSIS
        Tests TCP port connectivity to a remote host.
    
    .DESCRIPTION
        Performs a TCP connection test to verify network connectivity and port availability.
        Useful for pre-deployment checks, health monitoring, and troubleshooting.
    
    .PARAMETER ComputerName
        The target computer name or IP address.
    
    .PARAMETER Port
        The TCP port number to test.
    
    .PARAMETER TimeoutSeconds
        Connection timeout in seconds. Default is 5.
    
    .EXAMPLE
        Test-TcpPort -ComputerName "webserver01" -Port 443
        
        Tests HTTPS connectivity to webserver01.
    
    .EXAMPLE
        Test-TcpPort -ComputerName "sqlserver01.domain.com" -Port 1433 -TimeoutSeconds 10
        
        Tests SQL Server connectivity with 10-second timeout.
    
    .EXAMPLE
        @("SERVER01", "SERVER02", "SERVER03") | ForEach-Object {
            Test-TcpPort -ComputerName $_ -Port 3389
        }
        
        Tests RDP connectivity to multiple servers.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 5
    )
    
    process {
        $result = [PSCustomObject]@{
            ComputerName = $ComputerName
            Port         = $Port
            IsOpen       = $false
            ResponseTime = $null
            Error        = $null
            Timestamp    = Get-Date
        }
        
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Create TCP client
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            
            # Attempt connection
            $asyncResult = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
            $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000)
            
            if ($wait) {
                try {
                    $tcpClient.EndConnect($asyncResult)
                    $stopwatch.Stop()
                    
                    $result.IsOpen = $true
                    $result.ResponseTime = $stopwatch.ElapsedMilliseconds
                    
                    Write-Verbose "$ComputerName`:$Port is OPEN (${stopwatch.ElapsedMilliseconds}ms)"
                }
                catch {
                    $result.Error = $_.Exception.Message
                    Write-Verbose "$ComputerName`:$Port connection failed: $($_.Exception.Message)"
                }
            }
            else {
                $result.Error = "Connection timeout after $TimeoutSeconds seconds"
                Write-Verbose "$ComputerName`:$Port connection timeout"
            }
            
            $tcpClient.Close()
            $tcpClient.Dispose()
        }
        catch {
            $result.Error = $_.Exception.Message
            Write-Verbose "Error testing $ComputerName`:$Port - $($_.Exception.Message)"
        }
        
        return $result
    }
}
