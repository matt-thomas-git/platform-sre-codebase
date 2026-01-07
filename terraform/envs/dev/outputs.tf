# Outputs for Azure SQL Server VM Deployment

output "vm_id" {
  description = "The ID of the virtual machine"
  value       = azurerm_windows_virtual_machine.vm.id
}

output "vm_name" {
  description = "The name of the virtual machine"
  value       = azurerm_windows_virtual_machine.vm.name
}

output "vm_private_ip" {
  description = "The private IP address of the virtual machine"
  value       = azurerm_network_interface.nic.private_ip_address
}

output "vm_public_ip" {
  description = "The public IP address of the virtual machine"
  value       = azurerm_public_ip.public_ip.ip_address
}

output "vm_fqdn" {
  description = "The fully qualified domain name of the virtual machine"
  value       = azurerm_public_ip.public_ip.fqdn
}

output "data_disk_id" {
  description = "The ID of the data disk"
  value       = azurerm_managed_disk.data_disk.id
}

output "log_disk_id" {
  description = "The ID of the log disk"
  value       = azurerm_managed_disk.log_disk.id
}

output "nsg_id" {
  description = "The ID of the network security group"
  value       = azurerm_network_security_group.nsg.id
}

output "sql_vm_id" {
  description = "The ID of the SQL virtual machine resource"
  value       = azurerm_mssql_virtual_machine.sqlvm.id
}
