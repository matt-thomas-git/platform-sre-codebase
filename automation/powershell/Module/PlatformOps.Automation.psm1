# PlatformOps.Automation PowerShell Module
# Provides common automation functions for Platform SRE operations

# Get public and private function definition files
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in $Public) {
    try {
        . $import.FullName
        Write-Verbose "Imported function: $($import.BaseName)"
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $Public.BaseName

Write-Verbose "PlatformOps.Automation module loaded successfully"
