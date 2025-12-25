output "logic_app_id" {
  description = "The ID of the Logic App"
  value       = azurerm_logic_app_workflow.teams_notifier.id
}

output "logic_app_name" {
  description = "The name of the Logic App"
  value       = azurerm_logic_app_workflow.teams_notifier.name
}

output "logic_app_identity_principal_id" {
  description = "The Principal ID of the Logic App's Managed Identity"
  value       = azurerm_logic_app_workflow.teams_notifier.identity[0].principal_id
}

output "logic_app_access_endpoint" {
  description = "The access endpoint URL for the Logic App (base URL, not the trigger URL)"
  value       = azurerm_logic_app_workflow.teams_notifier.access_endpoint
}

output "resource_group_name" {
  description = "The resource group containing the Logic App"
  value       = local.resource_group_name
}

output "teams_connection_id" {
  description = "The ID of the Teams API connection"
  value       = azurerm_api_connection.teams.id
}
