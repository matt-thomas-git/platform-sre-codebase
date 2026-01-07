# Azure NSG Rules Module - Variables

# Required Variables
variable "resource_group_name" {
  description = "Name of the resource group containing the NSG"
  type        = string
}

variable "network_security_group_name" {
  description = "Name of the Network Security Group"
  type        = string
}

# Custom Security Rules
variable "security_rules" {
  description = "Map of custom security rules to create"
  type = map(object({
    priority                     = number
    direction                    = string
    access                       = string
    protocol                     = string
    source_port_range            = optional(string)
    source_port_ranges           = optional(list(string))
    destination_port_range       = optional(string)
    destination_port_ranges      = optional(list(string))
    source_address_prefix        = optional(string)
    source_address_prefixes      = optional(list(string))
    destination_address_prefix   = optional(string)
    destination_address_prefixes = optional(list(string))
    description                  = optional(string)
  }))
  default = {}
}

# Common Rules Configuration
variable "use_common_rules" {
  description = "Enable predefined common security rules"
  type        = bool
  default     = false
}

variable "enable_rdp_rule" {
  description = "Enable RDP access rule"
  type        = bool
  default     = false
}

variable "rdp_source_addresses" {
  description = "Source IP addresses allowed for RDP"
  type        = list(string)
  default     = []
}

variable "enable_winrm_rule" {
  description = "Enable WinRM access rule"
  type        = bool
  default     = false
}

variable "winrm_source_addresses" {
  description = "Source IP addresses allowed for WinRM"
  type        = list(string)
  default     = []
}

variable "enable_sql_rule" {
  description = "Enable SQL Server access rule"
  type        = bool
  default     = false
}

variable "sql_source_addresses" {
  description = "Source IP addresses allowed for SQL Server"
  type        = list(string)
  default     = []
}

variable "enable_https_rule" {
  description = "Enable HTTPS access rule"
  type        = bool
  default     = false
}

variable "enable_http_rule" {
  description = "Enable HTTP access rule"
  type        = bool
  default     = false
}

variable "enable_deny_all_inbound_rule" {
  description = "Enable deny all inbound traffic rule (lowest priority)"
  type        = bool
  default     = false
}
