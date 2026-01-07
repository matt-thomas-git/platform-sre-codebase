# Azure NSG Rules Module - Outputs

output "custom_rule_ids" {
  description = "Map of custom security rule names to their IDs"
  value       = { for k, v in azurerm_network_security_rule.rules : k => v.id }
}

output "common_rule_ids" {
  description = "Map of common security rule names to their IDs"
  value       = { for k, v in azurerm_network_security_rule.common_rules : k => v.id }
}

output "all_rule_names" {
  description = "List of all created security rule names"
  value = concat(
    [for k in keys(azurerm_network_security_rule.rules) : k],
    [for k in keys(azurerm_network_security_rule.common_rules) : k]
  )
}
