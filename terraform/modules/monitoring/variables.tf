# Azure Monitoring Module - Variables

# Required Variables
variable "resource_name_prefix" {
  description = "Prefix for resource names"
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

# Log Analytics Workspace
variable "create_log_analytics_workspace" {
  description = "Create a new Log Analytics workspace"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
  default     = ""
}

variable "log_analytics_sku" {
  description = "SKU for Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_days" {
  description = "Retention period in days for Log Analytics"
  type        = number
  default     = 30
}

variable "existing_log_analytics_workspace_id" {
  description = "ID of existing Log Analytics workspace (if not creating new one)"
  type        = string
  default     = null
}

# Action Group
variable "create_action_group" {
  description = "Create an action group for alerts"
  type        = bool
  default     = true
}

variable "action_group_name" {
  description = "Name of the action group"
  type        = string
  default     = ""
}

variable "action_group_short_name" {
  description = "Short name for the action group (max 12 characters)"
  type        = string
  default     = "sre-alerts"
}

variable "email_receivers" {
  description = "List of email receivers for alerts"
  type = list(object({
    name          = string
    email_address = string
  }))
  default = []
}

variable "webhook_receivers" {
  description = "List of webhook receivers for alerts"
  type = list(object({
    name        = string
    service_uri = string
  }))
  default = []
}

# Alert Scopes
variable "alert_scopes" {
  description = "List of resource IDs to monitor"
  type        = list(string)
  default     = []
}

# CPU Alert
variable "enable_cpu_alert" {
  description = "Enable CPU percentage alert"
  type        = bool
  default     = true
}

variable "cpu_threshold_percentage" {
  description = "CPU percentage threshold for alert"
  type        = number
  default     = 85
}

variable "cpu_alert_severity" {
  description = "Severity of CPU alert (0-4, 0 is most severe)"
  type        = number
  default     = 2
}

# Memory Alert
variable "enable_memory_alert" {
  description = "Enable memory alert"
  type        = bool
  default     = true
}

variable "memory_threshold_bytes" {
  description = "Available memory threshold in bytes for alert"
  type        = number
  default     = 1073741824 # 1 GB
}

variable "memory_alert_severity" {
  description = "Severity of memory alert (0-4, 0 is most severe)"
  type        = number
  default     = 2
}

# Disk Alert
variable "enable_disk_alert" {
  description = "Enable disk alert"
  type        = bool
  default     = true
}

variable "disk_queue_depth_threshold" {
  description = "Disk queue depth threshold for alert"
  type        = number
  default     = 10
}

variable "disk_alert_severity" {
  description = "Severity of disk alert (0-4, 0 is most severe)"
  type        = number
  default     = 2
}

# Windows Event Alert
variable "enable_windows_event_alert" {
  description = "Enable Windows Event Log error alert"
  type        = bool
  default     = false
}

variable "windows_event_error_threshold" {
  description = "Number of errors to trigger alert"
  type        = number
  default     = 5
}

variable "windows_event_alert_severity" {
  description = "Severity of Windows Event alert (0-4, 0 is most severe)"
  type        = number
  default     = 3
}

# Diagnostic Settings
variable "enable_diagnostic_settings" {
  description = "Enable diagnostic settings"
  type        = bool
  default     = false
}

variable "diagnostic_setting_target_resource_ids" {
  description = "List of resource IDs to enable diagnostics on"
  type        = list(string)
  default     = []
}

variable "diagnostic_metrics" {
  description = "List of metric categories to enable"
  type        = list(string)
  default     = ["AllMetrics"]
}

variable "diagnostic_logs" {
  description = "List of log categories to enable"
  type        = list(string)
  default     = []
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
