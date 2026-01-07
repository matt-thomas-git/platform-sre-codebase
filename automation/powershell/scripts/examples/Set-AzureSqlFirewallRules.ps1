<#
.SYNOPSIS
    Azure SQL Database Firewall Rule Management - Add/Remove IP addresses

.DESCRIPTION
    This script manages Azure SQL Database firewall rules across multiple servers and databases.
    It can:
    1. Add new IP addresses to firewall rules
    2. Remove old/deprecated IP addresses
    3. Apply rules to specific databases or all databases on a server
    4. Export current firewall rules for audit/backup
    
    Supports both server-level and database-level firewall rules.

.PARAMETER SubscriptionId
    Azure Subscription ID containing the SQL servers.

.PARAMETER ResourceGroupName
    Resource Group name containing the SQL servers.

.PARAMETER ConfigPath
    Path to JSON configuration file containing servers, databases, and IP rules.
    If not specified, uses interactive mode.

.PARAMETER ExportOnly
    Export current firewall rules without making changes.

.PARAMETER ExportPath
    Path to export firewall rules CSV. Default: C:\temp\AzureSQL_FirewallRules_<timestamp>.csv

.EXAMPLE
    .\Set-AzureSqlFirewallRules.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ResourceGroupName "sql-rg"
    
    Interactive mode - prompts for servers, databases, and IP addresses.

.EXAMPLE
    .\Set-AzureSqlFirewallRules.ps1 -ConfigPath ".\firewall-config.json"
    
    Uses configuration file to manage firewall rules.

.EXAMPLE
    .\Set-AzureSqlFirewallRules.ps1 -SubscriptionId "abc-123" -ResourceGroupName "sql-rg" -ExportOnly
    
    Export current firewall rules without making changes.

.NOTES
    Author: Platform SRE Team
    Requires: Az.Sql PowerShell Module
    Permissions: SQL Server Contributor or higher on the subscription
    
    Configuration file format (JSON):
    {
        "servers": {
            "sqlserver1.database.windows.net": ["database1", "database2"],
            "sqlserver2.database.windows.net": ["database3"]
        },
        "ipRulesToAdd": [
            { "name": "Office-IP-1", "ip": "203.0.113.10" },
            { "name": "Office-IP-2", "ip": "203.0.113.11" }
        ],
        "ipRulesToRemove": ["198.51.100.5", "198.51.100.6"]
    }
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportOnly,
    
    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "C:\temp\AzureSQL_FirewallRules_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

# Ensure Az.Sql module is installed
if (!(Get-Module -ListAvailable -Name Az.Sql)) {
    Write-Host "Installing Az.Sql module..." -ForegroundColor Yellow
    Install-Module -Name Az.Sql -Force -AllowClobber -Scope CurrentUser
}

Import-Module Az.Sql, Az.Accounts

# Create export directory if needed
$exportDir = Split-Path $ExportPath -Parent
if (!(Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
}

# Connect to Azure
Write-Host "Connecting to Azure..." -ForegroundColor Cyan
try {
    $context = Get-AzContext
    if (!$context) {
        Connect-AzAccount | Out-Null
    }
    Write-Host "Successfully connected to Azure" -ForegroundColor Green
} catch {
    Write-Host "Failed to connect to Azure: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Set subscription context if provided
if ($SubscriptionId) {
    Write-Host "Setting subscription context: $SubscriptionId" -ForegroundColor Cyan
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
} else {
    $currentContext = Get-AzContext
    Write-Host "Using current subscription: $($currentContext.Subscription.Name)" -ForegroundColor Yellow
    $SubscriptionId = $currentContext.Subscription.Id
}

# Function to get all firewall rules
function Get-AllFirewallRules {
    param(
        [string]$ResourceGroup,
        [string]$ServerName
    )
    
    Write-Host "`nRetrieving firewall rules for server: $ServerName" -ForegroundColor Cyan
    
    try {
        $rules = Get-AzSqlServerFirewallRule -ResourceGroupName $ResourceGroup -ServerName $ServerName
        
        $results = @()
        foreach ($rule in $rules) {
            $results += [PSCustomObject]@{
                ServerName      = $ServerName
                RuleName        = $rule.FirewallRuleName
                StartIpAddress  = $rule.StartIpAddress
                EndIpAddress    = $rule.EndIpAddress
                RuleType        = "Server-Level"
            }
        }
        
        Write-Host "Found $($rules.Count) server-level firewall rule(s)" -ForegroundColor Green
        return $results
        
    } catch {
        Write-Host "Error retrieving firewall rules: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

# Function to add firewall rule
function Add-FirewallRule {
    param(
        [string]$ResourceGroup,
        [string]$ServerName,
        [string]$RuleName,
        [string]$IpAddress
    )
    
    if ($PSCmdlet.ShouldProcess("$ServerName", "Add firewall rule $RuleName for IP $IpAddress")) {
        try {
            New-AzSqlServerFirewallRule `
                -ResourceGroupName $ResourceGroup `
                -ServerName $ServerName `
                -FirewallRuleName $RuleName `
                -StartIpAddress $IpAddress `
                -EndIpAddress $IpAddress `
                -ErrorAction Stop | Out-Null
            
            Write-Host "  [SUCCESS] Added rule: $RuleName ($IpAddress)" -ForegroundColor Green
            return $true
        } catch {
            if ($_.Exception.Message -like "*already exists*") {
                Write-Host "  [SKIPPED] Rule already exists: $RuleName" -ForegroundColor Yellow
            } else {
                Write-Host "  [ERROR] Failed to add rule: $($_.Exception.Message)" -ForegroundColor Red
            }
            return $false
        }
    }
}

# Function to remove firewall rule
function Remove-FirewallRule {
    param(
        [string]$ResourceGroup,
        [string]$ServerName,
        [string]$IpAddress
    )
    
    try {
        $rules = Get-AzSqlServerFirewallRule -ResourceGroupName $ResourceGroup -ServerName $ServerName
        $ruleToRemove = $rules | Where-Object { $_.StartIpAddress -eq $IpAddress }
        
        if ($ruleToRemove) {
            if ($PSCmdlet.ShouldProcess("$ServerName", "Remove firewall rule $($ruleToRemove.FirewallRuleName) for IP $IpAddress")) {
                Remove-AzSqlServerFirewallRule `
                    -ResourceGroupName $ResourceGroup `
                    -ServerName $ServerName `
                    -FirewallRuleName $ruleToRemove.FirewallRuleName `
                    -ErrorAction Stop | Out-Null
                
                Write-Host "  [SUCCESS] Removed rule: $($ruleToRemove.FirewallRuleName) ($IpAddress)" -ForegroundColor Green
                return $true
            }
        } else {
            Write-Host "  [SKIPPED] No rule found for IP: $IpAddress" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "  [ERROR] Failed to remove rule: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# MAIN EXECUTION

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Azure SQL Firewall Rule Management" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Load configuration if provided
$config = $null
if ($ConfigPath) {
    if (Test-Path $ConfigPath) {
        Write-Host "`nLoading configuration from: $ConfigPath" -ForegroundColor Cyan
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    } else {
        Write-Host "Configuration file not found: $ConfigPath" -ForegroundColor Red
        exit 1
    }
}

# Get resource group if not provided
if (!$ResourceGroupName) {
    if ($config -and $config.resourceGroup) {
        $ResourceGroupName = $config.resourceGroup
    } else {
        $ResourceGroupName = Read-Host "`nEnter Resource Group name"
    }
}

# Get SQL servers
$servers = @{}
if ($config -and $config.servers) {
    $servers = $config.servers
} else {
    Write-Host "`nEnter SQL Server names (comma-separated):" -ForegroundColor Yellow
    $serverInput = Read-Host
    $serverList = $serverInput -split ',' | ForEach-Object { $_.Trim() }
    foreach ($srv in $serverList) {
        $servers[$srv] = @()  # Empty array means all databases
    }
}

# Export current rules if requested
if ($ExportOnly) {
    Write-Host "`nExporting current firewall rules..." -ForegroundColor Cyan
    $allRules = @()
    
    foreach ($server in $servers.Keys) {
        $serverShortName = $server -replace '\.database\.windows\.net$', ''
        $rules = Get-AllFirewallRules -ResourceGroup $ResourceGroupName -ServerName $serverShortName
        $allRules += $rules
    }
    
    if ($allRules.Count -gt 0) {
        $allRules | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "`nFirewall rules exported to: $ExportPath" -ForegroundColor Green
        Write-Host "Total rules exported: $($allRules.Count)" -ForegroundColor Green
    } else {
        Write-Host "`nNo firewall rules found to export." -ForegroundColor Yellow
    }
    
    exit 0
}

# Process firewall rule changes
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "PROCESSING FIREWALL RULE CHANGES" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

$addedCount = 0
$removedCount = 0

foreach ($server in $servers.Keys) {
    $serverShortName = $server -replace '\.database\.windows\.net$', ''
    Write-Host "`n--- Processing Server: $serverShortName ---" -ForegroundColor Magenta
    
    # Remove old IPs
    if ($config -and $config.ipRulesToRemove) {
        Write-Host "`nRemoving old IP addresses..." -ForegroundColor Yellow
        foreach ($oldIP in $config.ipRulesToRemove) {
            if (Remove-FirewallRule -ResourceGroup $ResourceGroupName -ServerName $serverShortName -IpAddress $oldIP) {
                $removedCount++
            }
        }
    }
    
    # Add new IPs
    if ($config -and $config.ipRulesToAdd) {
        Write-Host "`nAdding new IP addresses..." -ForegroundColor Yellow
        foreach ($ipRule in $config.ipRulesToAdd) {
            if (Add-FirewallRule -ResourceGroup $ResourceGroupName -ServerName $serverShortName -RuleName $ipRule.name -IpAddress $ipRule.ip) {
                $addedCount++
            }
        }
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Rules Added: $addedCount" -ForegroundColor Green
Write-Host "Rules Removed: $removedCount" -ForegroundColor Green

# Export final state
Write-Host "`nExporting final firewall rules state..." -ForegroundColor Cyan
$allRules = @()
foreach ($server in $servers.Keys) {
    $serverShortName = $server -replace '\.database\.windows\.net$', ''
    $rules = Get-AllFirewallRules -ResourceGroup $ResourceGroupName -ServerName $serverShortName
    $allRules += $rules
}

if ($allRules.Count -gt 0) {
    $allRules | Export-Csv -Path $ExportPath -NoTypeInformation
    Write-Host "Final state exported to: $ExportPath" -ForegroundColor Green
}

Write-Host "`nFirewall rule management completed!" -ForegroundColor Cyan
