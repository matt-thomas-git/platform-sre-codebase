# Azure Windows VM Module
# Reusable module for deploying Windows VMs with managed disks and optional SQL Server

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "vm" {
  name                     = var.vm_name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  size                     = var.vm_size
  admin_username           = var.admin_username
  admin_password           = var.admin_password
  network_interface_ids    = var.network_interface_ids
  enable_automatic_updates = var.enable_automatic_updates
  patch_mode               = var.patch_mode
  patch_assessment_mode    = var.patch_assessment_mode
  timezone                 = var.timezone

  # Azure Hybrid Benefit for Windows Server
  license_type = var.license_type

  os_disk {
    name                 = "${var.vm_name}-osdisk"
    caching              = var.os_disk_caching
    disk_size_gb         = var.os_disk_size_gb
    storage_account_type = var.os_disk_storage_type
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  # Boot diagnostics
  boot_diagnostics {
    storage_account_uri = var.boot_diagnostics_storage_uri
  }

  tags = merge(
    var.tags,
    {
      managed_by = "terraform"
    }
  )

  lifecycle {
    ignore_changes = var.lifecycle_ignore_changes
  }
}

# Managed Data Disks
resource "azurerm_managed_disk" "data_disks" {
  for_each = var.data_disks

  name                 = "${var.vm_name}-${each.key}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = each.value.storage_account_type
  create_option        = "Empty"
  disk_size_gb         = each.value.disk_size_gb

  tags = merge(
    var.tags,
    {
      managed_by = "terraform"
      disk_type  = each.key
    }
  )

  lifecycle {
    ignore_changes = var.lifecycle_ignore_changes
  }
}

# Attach Data Disks to VM
resource "azurerm_virtual_machine_data_disk_attachment" "data_disk_attachments" {
  for_each = var.data_disks

  managed_disk_id    = azurerm_managed_disk.data_disks[each.key].id
  virtual_machine_id = azurerm_windows_virtual_machine.vm.id
  lun                = each.value.lun
  caching            = each.value.caching

  depends_on = [azurerm_windows_virtual_machine.vm]
}

# SQL Server VM Extension (optional)
resource "azurerm_mssql_virtual_machine" "sqlvm" {
  count = var.enable_sql_vm ? 1 : 0

  virtual_machine_id               = azurerm_windows_virtual_machine.vm.id
  sql_license_type                 = var.sql_license_type
  r_services_enabled               = var.sql_r_services_enabled
  sql_connectivity_port            = var.sql_connectivity_port
  sql_connectivity_type            = var.sql_connectivity_type
  sql_connectivity_update_password = var.admin_password
  sql_connectivity_update_username = var.admin_username

  dynamic "auto_patching" {
    for_each = var.sql_auto_patching_enabled ? [1] : []
    content {
      day_of_week                            = var.sql_auto_patching_day_of_week
      maintenance_window_duration_in_minutes = var.sql_auto_patching_maintenance_window_duration
      maintenance_window_starting_hour       = var.sql_auto_patching_maintenance_window_starting_hour
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = var.lifecycle_ignore_changes
  }

  depends_on = [azurerm_windows_virtual_machine.vm]
}

# VM Extension - Custom Script (optional)
resource "azurerm_virtual_machine_extension" "custom_script" {
  count = var.custom_script_enabled ? 1 : 0

  name                 = "${var.vm_name}-custom-script"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = var.custom_script_command
  })

  tags = var.tags

  depends_on = [azurerm_windows_virtual_machine.vm]
}

# Deletion Lock (optional)
resource "azurerm_management_lock" "vm_lock" {
  count = var.enable_deletion_lock ? 1 : 0

  name       = "lock-${var.vm_name}"
  scope      = azurerm_windows_virtual_machine.vm.id
  lock_level = "CanNotDelete"
  notes      = var.deletion_lock_notes

  depends_on = [azurerm_windows_virtual_machine.vm]
}
