<#
.SYNOPSIS
    Azure Virtual Network Creation with Subnets and NSGs

.DESCRIPTION
    Creates Azure Virtual Networks with subnets, Network Security Groups, and service endpoints.
    Supports configuration-driven deployment for repeatable infrastructure provisioning.

.PARAMETER SubscriptionId
    Azure Subscription ID

.PARAMETER ResourceGroupName
    Resource Group name for the VNet

.PARAMETER VNetName
    Virtual Network name

.PARAMETER Location
    Azure region (e.g., eastus2, westeurope)

.PARAMETER AddressPrefix
    VNet address space (e.g., 10.0.0.0/16)

.PARAMETER ConfigPath
    Path to JSON configuration file

.EXAMPLE
    .\New-AzureVirtualNetwork.ps1 -ResourceGroupName "network-rg" -VNetName "prod-vnet" -Location "eastus2" -AddressPrefix "10.0.0.0/16"

.EXAMPLE
    .\New-AzureVirtualNetwork.ps1 -ConfigPath ".\config\vnet-config.json" -WhatIf

.NOTES
    Author: Platform SRE Team
    Requires: Az.Network, Az.Accounts modules
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SubscriptionId,
    [string]$ResourceGroupName,
    [string]$VNetName,
    [string]$Location,
    [string]$AddressPrefix,
    [string]$ConfigPath
)

# Import required modules
$requiredModules = @('Az.Network', 'Az.Accounts', 'Az.Resources')
foreach ($module in $requiredModules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing module: $module" -ForegroundColor Yellow
        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
    }
}

Import-Module Az.Network, Az.Accounts, Az.Resources

# Connect to Azure
Write-Host "`nConnecting to Azure..." -ForegroundColor Cyan
$context = Get-AzContext
if (!$context) {
    Connect-AzAccount | Out-Null
}

if ($SubscriptionId) {
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
}

# Load configuration
if ($ConfigPath) {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $ResourceGroupName = $config.resourceGroup
    $VNetName = $config.vnetName
    $Location = $config.location
    $AddressPrefix = $config.addressPrefix
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Azure Virtual Network Creation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VNet Name: $VNetName" -ForegroundColor White
Write-Host "Address Space: $AddressPrefix" -ForegroundColor White
Write-Host "Location: $Location" -ForegroundColor White

# Create Resource Group
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (!$rg) {
    if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Create Resource Group")) {
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
        Write-Host "✓ Resource Group created" -ForegroundColor Green
    }
}

# Create subnets
$subnets = @()
if ($config.subnets) {
    foreach ($subnetConfig in $config.subnets) {
        $subnet = New-AzVirtualNetworkSubnetConfig `
            -Name $subnetConfig.name `
            -AddressPrefix $subnetConfig.addressPrefix
        $subnets += $subnet
        Write-Host "✓ Subnet configured: $($subnetConfig.name) - $($subnetConfig.addressPrefix)" -ForegroundColor Green
    }
}

# Create VNet
if ($PSCmdlet.ShouldProcess($VNetName, "Create Virtual Network")) {
    $vnet = New-AzVirtualNetwork `
        -Name $VNetName `
        -ResourceGroupName $ResourceGroupName `
        -Location $Location `
        -AddressPrefix $AddressPrefix `
        -Subnet $subnets
    
    Write-Host "✓ Virtual Network created successfully" -ForegroundColor Green
    Write-Host "  VNet ID: $($vnet.Id)" -ForegroundColor Gray
}

Write-Host "`n✓ VNet deployment completed!" -ForegroundColor Cyan
