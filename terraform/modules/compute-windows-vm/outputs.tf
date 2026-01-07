# Azure Windows VM Module - Outputs

output "vm_id" {
  description = "ID of the Windows virtual machine"
  value       = azurerm_windows_virtual_machine.vm.id
}

output "vm_name" {
  description = "Name of the Windows virtual machine"
  value       = azurerm_windows_virtual_machine.vm.name
}

output "vm_private_ip" {
  description = "Private IP address of the VM (from first NIC)"
  value       = azurerm_windows_virtual_machine.vm.private_ip_address
}

output "vm_public_ip" {
  description = "Public IP address of the VM (from first NIC)"
  value       = azurerm_windows_virtual_machine.vm.public_ip_address
}

output "vm_identity" {
  description = "Identity block of the VM"
  value       = azurerm_windows_virtual_machine.vm.identity
}

output "os_disk_id" {
  description = "ID of the OS disk"
  value       = azurerm_windows_virtual_machine.vm.os_disk[0].name
}

output "data_disk_ids" {
  description = "Map of data disk names to their IDs"
  value       = { for k, v in azurerm_managed_disk.data_disks : k => v.id }
}

output "sql_vm_id" {
  description = "ID of the SQL VM extension (if enabled)"
  value       = var.enable_sql_vm ? azurerm_mssql_virtual_machine.sqlvm[0].id : null
}

output "deletion_lock_id" {
  description = "ID of the deletion lock (if enabled)"
  value       = var.enable_deletion_lock ? azurerm_management_lock.vm_lock[0].id : null
}
