# Azure NSG Rules Module
# Reusable module for creating Network Security Group rules

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Network Security Group Rules
resource "azurerm_network_security_rule" "rules" {
  for_each = var.security_rules

  name                        = each.key
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = lookup(each.value, "source_port_range", null)
  source_port_ranges          = lookup(each.value, "source_port_ranges", null)
  destination_port_range      = lookup(each.value, "destination_port_range", null)
  destination_port_ranges     = lookup(each.value, "destination_port_ranges", null)
  source_address_prefix       = lookup(each.value, "source_address_prefix", null)
  source_address_prefixes     = lookup(each.value, "source_address_prefixes", null)
  destination_address_prefix  = lookup(each.value, "destination_address_prefix", null)
  destination_address_prefixes = lookup(each.value, "destination_address_prefixes", null)
  description                 = lookup(each.value, "description", null)
  resource_group_name         = var.resource_group_name
  network_security_group_name = var.network_security_group_name
}

# Common predefined rules (optional)
locals {
  common_rules = {
    allow_rdp = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefixes    = var.rdp_source_addresses
      destination_address_prefix = "*"
      description                = "Allow RDP from specified sources"
    }
    allow_winrm = {
      priority                   = 101
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["5985", "5986"]
      source_address_prefixes    = var.winrm_source_addresses
      destination_address_prefix = "*"
      description                = "Allow WinRM from specified sources"
    }
    allow_sql = {
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "1433"
      source_address_prefixes    = var.sql_source_addresses
      destination_address_prefix = "*"
      description                = "Allow SQL Server from specified sources"
    }
    allow_https = {
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Allow HTTPS from anywhere"
    }
    allow_http = {
      priority                   = 121
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Allow HTTP from anywhere"
    }
    deny_all_inbound = {
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Deny all other inbound traffic"
    }
  }

  # Filter common rules based on enabled flags
  enabled_common_rules = {
    for k, v in local.common_rules :
    k => v
    if(
      (k == "allow_rdp" && var.enable_rdp_rule) ||
      (k == "allow_winrm" && var.enable_winrm_rule) ||
      (k == "allow_sql" && var.enable_sql_rule) ||
      (k == "allow_https" && var.enable_https_rule) ||
      (k == "allow_http" && var.enable_http_rule) ||
      (k == "deny_all_inbound" && var.enable_deny_all_inbound_rule)
    )
  }
}

# Create common predefined rules
resource "azurerm_network_security_rule" "common_rules" {
  for_each = var.use_common_rules ? local.enabled_common_rules : {}

  name                         = each.key
  priority                     = each.value.priority
  direction                    = each.value.direction
  access                       = each.value.access
  protocol                     = each.value.protocol
  source_port_range            = lookup(each.value, "source_port_range", null)
  source_port_ranges           = lookup(each.value, "source_port_ranges", null)
  destination_port_range       = lookup(each.value, "destination_port_range", null)
  destination_port_ranges      = lookup(each.value, "destination_port_ranges", null)
  source_address_prefix        = lookup(each.value, "source_address_prefix", null)
  source_address_prefixes      = lookup(each.value, "source_address_prefixes", null)
  destination_address_prefix   = lookup(each.value, "destination_address_prefix", null)
  destination_address_prefixes = lookup(each.value, "destination_address_prefixes", null)
  description                  = lookup(each.value, "description", null)
  resource_group_name          = var.resource_group_name
  network_security_group_name  = var.network_security_group_name
}
