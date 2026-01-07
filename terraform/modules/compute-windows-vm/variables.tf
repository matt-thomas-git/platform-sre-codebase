# Azure Windows VM Module - Variables

# Required Variables
variable "vm_name" {
  description = "Name of the Windows virtual machine"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "vm_size" {
  description = "Size of the virtual machine (e.g., Standard_D4s_v3)"
  type        = string
}

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Administrator password for the VM"
  type        = string
  sensitive   = true
}

variable "network_interface_ids" {
  description = "List of network interface IDs to attach to the VM"
  type        = list(string)
}

# OS Disk Configuration
variable "os_disk_caching" {
  description = "Caching type for OS disk (ReadWrite, ReadOnly, None)"
  type        = string
  default     = "ReadWrite"
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 128
}

variable "os_disk_storage_type" {
  description = "Storage account type for OS disk (Standard_LRS, StandardSSD_LRS, Premium_LRS)"
  type        = string
  default     = "StandardSSD_LRS"
}

# Image Configuration
variable "image_publisher" {
  description = "Publisher of the VM image"
  type        = string
  default     = "MicrosoftWindowsServer"
}

variable "image_offer" {
  description = "Offer of the VM image"
  type        = string
  default     = "WindowsServer"
}

variable "image_sku" {
  description = "SKU of the VM image"
  type        = string
  default     = "2019-Datacenter"
}

variable "image_version" {
  description = "Version of the VM image"
  type        = string
  default     = "latest"
}

# Patching Configuration
variable "enable_automatic_updates" {
  description = "Enable automatic Windows updates"
  type        = bool
  default     = false
}

variable "patch_mode" {
  description = "Patch mode for the VM (Manual, AutomaticByOS, AutomaticByPlatform)"
  type        = string
  default     = "Manual"
}

variable "patch_assessment_mode" {
  description = "Patch assessment mode (ImageDefault, AutomaticByPlatform)"
  type        = string
  default     = "AutomaticByPlatform"
}

variable "timezone" {
  description = "Timezone for the VM"
  type        = string
  default     = "UTC"
}

# Azure Hybrid Benefit
variable "license_type" {
  description = "License type for Azure Hybrid Benefit (Windows_Server, Windows_Client, None)"
  type        = string
  default     = "Windows_Server"
}

# Data Disks Configuration
variable "data_disks" {
  description = "Map of data disks to create and attach"
  type = map(object({
    disk_size_gb         = number
    storage_account_type = string
    lun                  = number
    caching              = string
  }))
  default = {}
}

# Boot Diagnostics
variable "boot_diagnostics_storage_uri" {
  description = "Storage account URI for boot diagnostics (null for managed storage)"
  type        = string
  default     = null
}

# SQL Server Configuration
variable "enable_sql_vm" {
  description = "Enable SQL Server VM extension"
  type        = bool
  default     = false
}

variable "sql_license_type" {
  description = "SQL Server license type (PAYG, AHUB, DR)"
  type        = string
  default     = "AHUB"
}

variable "sql_r_services_enabled" {
  description = "Enable SQL Server R Services"
  type        = bool
  default     = false
}

variable "sql_connectivity_port" {
  description = "SQL Server connectivity port"
  type        = number
  default     = 1433
}

variable "sql_connectivity_type" {
  description = "SQL Server connectivity type (LOCAL, PRIVATE, PUBLIC)"
  type        = string
  default     = "PRIVATE"
}

variable "sql_auto_patching_enabled" {
  description = "Enable SQL Server auto patching"
  type        = bool
  default     = false
}

variable "sql_auto_patching_day_of_week" {
  description = "Day of week for SQL Server auto patching (Sunday, Monday, etc.)"
  type        = string
  default     = "Sunday"
}

variable "sql_auto_patching_maintenance_window_duration" {
  description = "Maintenance window duration in minutes for SQL Server auto patching"
  type        = number
  default     = 60
}

variable "sql_auto_patching_maintenance_window_starting_hour" {
  description = "Starting hour for SQL Server auto patching maintenance window (0-23)"
  type        = number
  default     = 2
}

# Custom Script Extension
variable "custom_script_enabled" {
  description = "Enable custom script extension"
  type        = bool
  default     = false
}

variable "custom_script_command" {
  description = "Command to execute via custom script extension"
  type        = string
  default     = ""
}

# Deletion Lock
variable "enable_deletion_lock" {
  description = "Enable deletion lock on the VM"
  type        = bool
  default     = false
}

variable "deletion_lock_notes" {
  description = "Notes for the deletion lock"
  type        = string
  default     = "Lock to prevent accidental deletion"
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Lifecycle
variable "lifecycle_ignore_changes" {
  description = "List of attributes to ignore changes on"
  type        = list(string)
  default     = ["tags"]
}
