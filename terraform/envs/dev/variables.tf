# Variables for Azure SQL Server VM Deployment - DEV Environment

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the existing Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
}

variable "vnet_resource_group_name" {
  description = "Name of the resource group where the virtual network is located"
  type        = string
}

variable "vnet_name" {
  description = "Name of the existing Virtual Network"
  type        = string
}

variable "subnet_name" {
  description = "Name of the existing Subnet"
  type        = string
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "vm_size" {
  description = "Size of the virtual machine (e.g., Standard_E4ds_v5)"
  type        = string
}

variable "nic_name" {
  description = "The name of the network interface"
  type        = string
}

variable "public_ip_name" {
  description = "The name of the public IP address"
  type        = string
}

variable "domain_name_label" {
  description = "The domain name label for the public IP"
  type        = string
}

variable "private_ip_address" {
  description = "The static private IP address to assign to the VM NIC"
  type        = string
}

variable "sql_publisher" {
  description = "Publisher of the SQL Server image"
  type        = string
  default     = "MicrosoftSQLServer"
}

variable "sql_offer" {
  description = "Offer for the SQL Server image"
  type        = string
  default     = "SQL2019-WS2019"
}

variable "sql_sku" {
  description = "SKU for the SQL Server image (e.g., Standard, Enterprise)"
  type        = string
  default     = "Standard"
}

variable "sql_version" {
  description = "Version of the SQL Server image"
  type        = string
  default     = "latest"
}

variable "sql_license_type" {
  description = "SQL Server license type: AHUB (Azure Hybrid Benefit) or PAYG (Pay As You Go)"
  type        = string
  default     = "AHUB"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Admin password for the VM"
  type        = string
  sensitive   = true
}

variable "sql_allowed_sources" {
  description = "List of IP addresses allowed to connect to SQL Server (port 1433)"
  type        = list(string)
  default     = [
    "10.0.0.0/8",      # Internal network
    "172.16.0.0/12",   # Internal network
    "192.168.0.0/16"   # Internal network
  ]
}

variable "azuredevops_sources" {
  description = "List of Azure DevOps IP ranges"
  type        = list(string)
  default     = [
    "52.164.184.0/22"  # Azure DevOps service tag range
  ]
}

variable "monitoring_sources" {
  description = "List of monitoring system IP addresses"
  type        = list(string)
  default     = [
    "10.252.28.48/28",
    "10.252.28.64/28",
    "10.252.28.80/28"
  ]
}
