# Azure Monitoring Module - Outputs

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.workspace[0].id : null
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.workspace[0].name : null
}

output "log_analytics_workspace_key" {
  description = "Primary shared key of the Log Analytics workspace"
  value       = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.workspace[0].primary_shared_key : null
  sensitive   = true
}

output "action_group_id" {
  description = "ID of the action group"
  value       = var.create_action_group ? azurerm_monitor_action_group.action_group[0].id : null
}

output "action_group_name" {
  description = "Name of the action group"
  value       = var.create_action_group ? azurerm_monitor_action_group.action_group[0].name : null
}

output "cpu_alert_id" {
  description = "ID of the CPU alert"
  value       = var.enable_cpu_alert ? azurerm_monitor_metric_alert.cpu_alert[0].id : null
}

output "memory_alert_id" {
  description = "ID of the memory alert"
  value       = var.enable_memory_alert ? azurerm_monitor_metric_alert.memory_alert[0].id : null
}

output "disk_alert_id" {
  description = "ID of the disk alert"
  value       = var.enable_disk_alert ? azurerm_monitor_metric_alert.disk_alert[0].id : null
}

output "windows_event_alert_id" {
  description = "ID of the Windows Event alert"
  value       = var.enable_windows_event_alert && var.create_log_analytics_workspace ? azurerm_monitor_scheduled_query_rules_alert_v2.windows_event_errors[0].id : null
}
