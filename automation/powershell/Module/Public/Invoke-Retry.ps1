function Invoke-Retry {
    <#
    .SYNOPSIS
        Executes a script block with retry logic and exponential backoff.
    
    .DESCRIPTION
        Provides robust retry logic for operations that may fail transiently.
        Implements exponential backoff to avoid overwhelming services.
        Commonly used for API calls, network operations, and database connections.
    
    .PARAMETER ScriptBlock
        The script block to execute with retry logic.
    
    .PARAMETER MaxRetries
        Maximum number of retry attempts. Default is 3.
    
    .PARAMETER InitialDelaySeconds
        Initial delay in seconds before first retry. Default is 2.
    
    .PARAMETER MaxDelaySeconds
        Maximum delay in seconds between retries. Default is 60.
    
    .PARAMETER ExponentialBackoff
        Use exponential backoff for retry delays. Default is $true.
    
    .EXAMPLE
        Invoke-Retry -ScriptBlock {
            Invoke-RestMethod -Uri "https://api.example.com/data" -Method Get
        }
        
        Retries an API call up to 3 times with exponential backoff.
    
    .EXAMPLE
        Invoke-Retry -ScriptBlock {
            Test-Connection -ComputerName "SERVER01" -Count 1 -ErrorAction Stop
        } -MaxRetries 5 -InitialDelaySeconds 5
        
        Retries a network connectivity test up to 5 times.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$InitialDelaySeconds = 2,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxDelaySeconds = 60,
        
        [Parameter(Mandatory = $false)]
        [bool]$ExponentialBackoff = $true
    )
    
    $attempt = 0
    $delay = $InitialDelaySeconds
    
    while ($attempt -le $MaxRetries) {
        try {
            $attempt++
            Write-Verbose "Attempt $attempt of $($MaxRetries + 1)"
            
            # Execute the script block
            $result = & $ScriptBlock
            
            Write-Verbose "Operation succeeded on attempt $attempt"
            return $result
        }
        catch {
            $lastError = $_
            
            if ($attempt -gt $MaxRetries) {
                Write-Error "Operation failed after $attempt attempts. Last error: $($lastError.Exception.Message)"
                throw $lastError
            }
            
            Write-Warning "Attempt $attempt failed: $($lastError.Exception.Message)"
            Write-Verbose "Retrying in $delay seconds..."
            
            Start-Sleep -Seconds $delay
            
            # Calculate next delay with exponential backoff
            if ($ExponentialBackoff) {
                $delay = [Math]::Min($delay * 2, $MaxDelaySeconds)
            }
        }
    }
}
