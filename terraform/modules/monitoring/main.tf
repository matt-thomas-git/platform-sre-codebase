# Azure Monitoring Module
# Reusable module for Azure Monitor alerts, Log Analytics, and diagnostic settings

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "workspace" {
  count = var.create_log_analytics_workspace ? 1 : 0

  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_days

  tags = merge(
    var.tags,
    {
      managed_by = "terraform"
    }
  )
}

# Action Group for Alert Notifications
resource "azurerm_monitor_action_group" "action_group" {
  count = var.create_action_group ? 1 : 0

  name                = var.action_group_name
  resource_group_name = var.resource_group_name
  short_name          = var.action_group_short_name

  dynamic "email_receiver" {
    for_each = var.email_receivers
    content {
      name                    = email_receiver.value.name
      email_address           = email_receiver.value.email_address
      use_common_alert_schema = true
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.webhook_receivers
    content {
      name                    = webhook_receiver.value.name
      service_uri             = webhook_receiver.value.service_uri
      use_common_alert_schema = true
    }
  }

  tags = var.tags
}

# Metric Alert: CPU Percentage
resource "azurerm_monitor_metric_alert" "cpu_alert" {
  count = var.enable_cpu_alert ? 1 : 0

  name                = "${var.resource_name_prefix}-cpu-alert"
  resource_group_name = var.resource_group_name
  scopes              = var.alert_scopes
  description         = "Alert when CPU percentage exceeds threshold"
  severity            = var.cpu_alert_severity
  frequency           = "PT5M"
  window_size         = "PT15M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.cpu_threshold_percentage
  }

  dynamic "action" {
    for_each = var.create_action_group ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.action_group[0].id
    }
  }

  tags = var.tags
}

# Metric Alert: Memory Percentage (requires Log Analytics)
resource "azurerm_monitor_metric_alert" "memory_alert" {
  count = var.enable_memory_alert ? 1 : 0

  name                = "${var.resource_name_prefix}-memory-alert"
  resource_group_name = var.resource_group_name
  scopes              = var.alert_scopes
  description         = "Alert when available memory is low"
  severity            = var.memory_alert_severity
  frequency           = "PT5M"
  window_size         = "PT15M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = var.memory_threshold_bytes
  }

  dynamic "action" {
    for_each = var.create_action_group ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.action_group[0].id
    }
  }

  tags = var.tags
}

# Metric Alert: Disk Space
resource "azurerm_monitor_metric_alert" "disk_alert" {
  count = var.enable_disk_alert ? 1 : 0

  name                = "${var.resource_name_prefix}-disk-alert"
  resource_group_name = var.resource_group_name
  scopes              = var.alert_scopes
  description         = "Alert when disk space is low"
  severity            = var.disk_alert_severity
  frequency           = "PT15M"
  window_size         = "PT30M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "OS Disk Queue Depth"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.disk_queue_depth_threshold
  }

  dynamic "action" {
    for_each = var.create_action_group ? [1] : []
    content {
      action_group_id = azurerm_monitor_action_group.action_group[0].id
    }
  }

  tags = var.tags
}

# Scheduled Query Alert: Windows Event Log Errors
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "windows_event_errors" {
  count = var.enable_windows_event_alert && var.create_log_analytics_workspace ? 1 : 0

  name                = "${var.resource_name_prefix}-windows-event-errors"
  resource_group_name = var.resource_group_name
  location            = var.location
  scopes              = [azurerm_log_analytics_workspace.workspace[0].id]
  description         = "Alert on Windows Event Log errors"
  severity            = var.windows_event_alert_severity
  enabled             = true
  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"

  criteria {
    query                   = <<-QUERY
      Event
      | where EventLevelName == "Error"
      | where TimeGenerated > ago(15m)
      | summarize count() by Computer, EventID
      | where count_ > ${var.windows_event_error_threshold}
    QUERY
    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  dynamic "action" {
    for_each = var.create_action_group ? [1] : []
    content {
      action_groups = [azurerm_monitor_action_group.action_group[0].id]
    }
  }

  tags = var.tags
}

# Diagnostic Settings for VM
resource "azurerm_monitor_diagnostic_setting" "vm_diagnostics" {
  count = var.enable_diagnostic_settings && length(var.diagnostic_setting_target_resource_ids) > 0 ? length(var.diagnostic_setting_target_resource_ids) : 0

  name                       = "${var.resource_name_prefix}-diagnostics-${count.index}"
  target_resource_id         = var.diagnostic_setting_target_resource_ids[count.index]
  log_analytics_workspace_id = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.workspace[0].id : var.existing_log_analytics_workspace_id

  # Metrics
  dynamic "metric" {
    for_each = var.diagnostic_metrics
    content {
      category = metric.value
      enabled  = true
    }
  }

  # Logs (if applicable)
  dynamic "enabled_log" {
    for_each = var.diagnostic_logs
    content {
      category = enabled_log.value
    }
  }
}
