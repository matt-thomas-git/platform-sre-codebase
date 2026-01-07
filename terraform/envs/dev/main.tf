# Azure SQL Server VM Deployment - DEV Environment
# This Terraform configuration deploys a Windows VM with SQL Server 2019 Standard
# Features: Azure Hybrid Benefit (AHUB), multiple managed disks, NSG rules, deletion lock

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Reference existing Resource Group
data "azurerm_resource_group" "existing_rg" {
  name = var.resource_group_name
}

# Reference existing Virtual Network
data "azurerm_virtual_network" "existing_vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

# Reference existing Subnet
data "azurerm_subnet" "existing_subnet" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.existing_vnet.name
  resource_group_name  = var.vnet_resource_group_name
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.vm_name}-nsg"
  location            = data.azurerm_resource_group.existing_rg.location
  resource_group_name = data.azurerm_resource_group.existing_rg.name

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Public IP (Static)
resource "azurerm_public_ip" "public_ip" {
  name                = var.public_ip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Basic"
  domain_name_label   = var.domain_name_label

  lifecycle {
    ignore_changes = [tags]
  }
}

# Network Interface with static private IP
resource "azurerm_network_interface" "nic" {
  name                = var.nic_name
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.existing_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.private_ip_address
    private_ip_address_version    = "IPv4"
    primary                       = true
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Managed Disk: Data (1TB Premium SSD)
resource "azurerm_managed_disk" "data_disk" {
  name                 = "${var.vm_name}-data-disk-0"
  location             = data.azurerm_resource_group.existing_rg.location
  resource_group_name  = data.azurerm_resource_group.existing_rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 1024

  lifecycle {
    ignore_changes = [tags]
  }
}

# Managed Disk: Log (512GB Premium SSD)
resource "azurerm_managed_disk" "log_disk" {
  name                 = "${var.vm_name}-log-disk-0"
  location             = data.azurerm_resource_group.existing_rg.location
  resource_group_name  = data.azurerm_resource_group.existing_rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 512
  
  lifecycle {
    ignore_changes = [tags]
  }
}

# Windows Virtual Machine with SQL Server 2019 Standard
resource "azurerm_windows_virtual_machine" "vm" {
  name                     = var.vm_name
  location                 = data.azurerm_resource_group.existing_rg.location
  resource_group_name      = data.azurerm_resource_group.existing_rg.name
  size                     = var.vm_size
  admin_username           = var.admin_username
  admin_password           = var.admin_password
  network_interface_ids    = [azurerm_network_interface.nic.id]
  enable_automatic_updates = false
  patch_mode               = "Manual"
  patch_assessment_mode    = "AutomaticByPlatform"

  # Azure Hybrid Benefit for Windows Server
  license_type = "Windows_Server"

  os_disk {
    name                 = "${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    disk_size_gb         = 128
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = var.sql_publisher
    offer     = var.sql_offer
    sku       = var.sql_sku
    version   = var.sql_version
  }

  tags = {
    environment = var.environment
    managed_by  = "terraform"
    workload    = "sql-server"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# SQL Server VM Extension - Azure Hybrid Benefit
resource "azurerm_mssql_virtual_machine" "sqlvm" {
  virtual_machine_id = azurerm_windows_virtual_machine.vm.id
  sql_license_type   = var.sql_license_type  # AHUB = Azure Hybrid Benefit

  lifecycle {
    ignore_changes = [tags]
  }
}

# Attach Data Disk (LUN 0, ReadWrite caching)
resource "azurerm_virtual_machine_data_disk_attachment" "data_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.data_disk.id
  virtual_machine_id = azurerm_windows_virtual_machine.vm.id
  lun                = 0
  caching            = "ReadWrite"
}

# Attach Log Disk (LUN 1, No caching for write performance)
resource "azurerm_virtual_machine_data_disk_attachment" "log_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.log_disk.id
  virtual_machine_id = azurerm_windows_virtual_machine.vm.id
  lun                = 1
  caching            = "None"
}

# Deletion Lock - Prevent accidental deletion
resource "azurerm_management_lock" "vm_lock" {
  name       = "lock-${var.vm_name}"
  scope      = azurerm_windows_virtual_machine.vm.id
  lock_level = "CanNotDelete"
  notes      = "Lock to prevent accidental deletion of production SQL Server"
}

# NSG Rule: Allow SQL Server (Port 1433) from specific sources
resource "azurerm_network_security_rule" "allow_sql" {
  name                        = "allow_sql"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefixes     = var.sql_allowed_sources
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.existing_rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# NSG Rule: Allow Azure DevOps
resource "azurerm_network_security_rule" "allow_azuredevops" {
  name                        = "allow_azuredevops"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefixes     = var.azuredevops_sources
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.existing_rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# NSG Rule: Allow Monitoring System
resource "azurerm_network_security_rule" "allow_monitoring" {
  name                        = "allow_monitoring"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = var.monitoring_sources
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.existing_rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Associate NSG with Network Interface
resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
