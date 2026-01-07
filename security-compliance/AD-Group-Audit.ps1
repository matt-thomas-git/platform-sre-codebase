<#
.SYNOPSIS
    Audits Active Directory groups containing "PROD" in their name and exports members to CSV.

.DESCRIPTION
    This script searches for AD groups with "PROD" in their name within the specified OU,
    retrieves all members of those groups, and exports the results to a date-stamped CSV file.
    The output directory (C:\temp) is created automatically if it doesn't exist.

.NOTES
    Author: Infrastructure Team
    Date: 2025-12-01
    OU Path: domain.local/domain.com/Groups/Servers_Sysadmin
#>

# Requires Active Directory module
#Requires -Modules ActiveDirectory

# Set error action preference
$ErrorActionPreference = "Stop"

# Define the OU path
$ouPath = "OU=Servers_Sysadmin,OU=Groups,OU=domain.com,DC=domain,DC=local"

# Define output directory and ensure it exists
$outputDir = "C:\temp"
if (-not (Test-Path -Path $outputDir)) {
    Write-Host "Creating output directory: $outputDir" -ForegroundColor Yellow
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    Write-Host "Output directory created successfully." -ForegroundColor Green
}

# Generate date-stamped filename with CO3 prefix
$dateStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outputFile = Join-Path -Path $outputDir -ChildPath "AD_PROD_Groups_Audit_$dateStamp.csv"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "AD PROD Groups Member Audit" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "OU Path: $ouPath" -ForegroundColor White
Write-Host "Output File: $outputFile`n" -ForegroundColor White

try {
    # Get all groups from the specified OU, excluding E4, DEV, QA, and UAT groups
    # This includes groups with PROD in the name, or any other groups (assumed to be PROD)
    Write-Host "Searching for PROD groups (excluding DEV, QA, UAT groups)..." -ForegroundColor Yellow
    
    $allGroups = Get-ADGroup -Filter "*" -SearchBase $ouPath -Properties Name, Description, MemberOf, Members
    
    $prodGroups = $allGroups | 
                  Where-Object { 
                      $_.Name -notlike '*DEV*' -and
                      $_.Name -notlike '*QA*' -and 
                      $_.Name -notlike '*UAT*'
                  } |
                  Sort-Object Name
    
    if ($prodGroups.Count -eq 0) {
        Write-Host "No PROD groups found in the specified OU." -ForegroundColor Red
        exit
    }
    
    Write-Host "Found $($prodGroups.Count) PROD group(s) (DEV, QA, UAT groups excluded).`n" -ForegroundColor Green
    
    # Initialize results array
    $results = @()
    
    # Process each group
    foreach ($group in $prodGroups) {
        Write-Host "Processing group: $($group.Name)" -ForegroundColor Cyan
        
        # Get group members
        $members = Get-ADGroupMember -Identity $group.DistinguishedName -Recursive | 
                   Where-Object { $_.objectClass -eq 'user' } |
                   Sort-Object Name
        
        if ($members.Count -eq 0) {
            Write-Host "  No members found in this group." -ForegroundColor Gray
            
            # Add entry for empty group
            $results += [PSCustomObject]@{
                GroupName = $group.Name
                GroupDescription = $group.Description
                MemberCount = 0
                MemberName = "N/A"
                MemberSamAccountName = "N/A"
                MemberDistinguishedName = "N/A"
                MemberObjectClass = "N/A"
                AuditDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
        else {
            Write-Host "  Found $($members.Count) member(s)" -ForegroundColor Green
            
            # Get detailed information for each member
            foreach ($member in $members) {
                try {
                    $userDetails = Get-ADUser -Identity $member.SamAccountName -Properties DisplayName, EmailAddress, Enabled, LastLogonDate
                    
                    $results += [PSCustomObject]@{
                        GroupName = $group.Name
                        GroupDescription = $group.Description
                        MemberCount = $members.Count
                        MemberName = $userDetails.DisplayName
                        MemberSamAccountName = $userDetails.SamAccountName
                        MemberEmail = $userDetails.EmailAddress
                        MemberEnabled = $userDetails.Enabled
                        MemberLastLogon = $userDetails.LastLogonDate
                        MemberDistinguishedName = $userDetails.DistinguishedName
                        MemberObjectClass = $member.objectClass
                        AuditDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                }
                catch {
                    Write-Host "  Warning: Could not retrieve details for $($member.SamAccountName)" -ForegroundColor Yellow
                    
                    $results += [PSCustomObject]@{
                        GroupName = $group.Name
                        GroupDescription = $group.Description
                        MemberCount = $members.Count
                        MemberName = $member.Name
                        MemberSamAccountName = $member.SamAccountName
                        MemberEmail = "N/A"
                        MemberEnabled = "N/A"
                        MemberLastLogon = "N/A"
                        MemberDistinguishedName = $member.DistinguishedName
                        MemberObjectClass = $member.objectClass
                        AuditDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                }
            }
        }
    }
    
    # Export results to CSV
    Write-Host "`nExporting results to CSV..." -ForegroundColor Yellow
    $results | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Audit Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Total Groups Processed: $($prodGroups.Count)" -ForegroundColor White
    Write-Host "Total Members Found: $($results.Count)" -ForegroundColor White
    Write-Host "Output File: $outputFile" -ForegroundColor White
    Write-Host "`nOpening output file..." -ForegroundColor Yellow
    
    # Open the CSV file
    Invoke-Item $outputFile
}
catch {
    Write-Host "`nError occurred during execution:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nStack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
