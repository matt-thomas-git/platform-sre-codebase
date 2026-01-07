$deploymentBasePath = "C$\inetpub\wwwroot\"  # Base folder where ClickOnce package may be stored
$targetServers = @("eescjuk", "eeabbottcldev", "eebayerukdev")  # List of servers to target dynamically

# Initialize results
$results = @()

# Get the local server name (collector/server running the script)
$serverExecutedOn = $env:COMPUTERNAME  # This will output the name of the machine executing the script

# Loop through each target server
foreach ($targetServer in $targetServers) {
    # Define the remote deployment path (on the target server)
    $deploymentPath = "\\$targetServer\$deploymentBasePath"

    # Prepare the status object for each target server
    $status = @{
        ServerExecutedOn = $serverExecutedOn  # The server running the script (LogicMonitor collector)
        TargetServer     = $targetServer      # The server we are targeting (e.g., eescjuk)
        CertValid        = 0  # Default to 0 (False)
        CertValidFrom    = $null  # Certificate start date
        CertValidTo      = $null  # Certificate expiry date
        Error            = $null  # Ensure it starts as null to prevent incorrect values
    }

    try {
        # Ensure that the remote path is accessible
        if (Test-Path -Path $deploymentPath) {
            # Search for the main ClickOnce deployment EXE in subfolders
            $packageExe = Get-ChildItem -Path $deploymentPath -Filter "Application.exe" -Recurse -ErrorAction Stop | Select-Object -First 1 -ExpandProperty FullName

            if ($packageExe) {
                # Check Authenticode Signature
                $signature = Get-AuthenticodeSignature -FilePath $packageExe -ErrorAction Stop

                # Check if the certificate is valid based on its validity dates
                $cert = $signature.SignerCertificate
                $currentDate = Get-Date

                # Extract only the date part
                $certNotBeforeDate = $cert.NotBefore.ToString("yyyy-MM-dd")
                $certNotAfterDate = $cert.NotAfter.ToString("yyyy-MM-dd")
                $currentDateOnly = $currentDate.ToString("yyyy-MM-dd")

                # Assign certificate validity dates
                $status.CertValidFrom = $certNotBeforeDate
                $status.CertValidTo = $certNotAfterDate

                # Check if certificate is valid
                if ($cert.NotBefore -le $currentDate -and $cert.NotAfter -ge $currentDate) {
                    $status.CertValid = 1  # Set to 1 (True) if valid
                }
            } else {
                $status.Error = "No Application.exe found in the deployment path or subfolders!"
            }
        } else {
            $status.Error = "Remote path is not available: $deploymentPath"
        }
    }
    catch {
        $status.Error = $_.Exception.Message
    }

    # Add status of the current target server to results
    $results += $status
}

# Output results in LogicMonitor-friendly format
foreach ($result in $results) {
    $output = @{
        TargetServer     = $result.TargetServer
        CertificateValid = $result.CertValid  # Outputs 0 or 1
        CertValidFrom    = $result.CertValidFrom
        CertValidTo      = $result.CertValidTo
    }

    # Output as JSON for LogicMonitor
    Write-Output ($output | ConvertTo-Json -Compress)
}
