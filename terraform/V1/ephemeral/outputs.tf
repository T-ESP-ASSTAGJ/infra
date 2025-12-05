output "api_fqdn" {
  description = "API Container App FQDN"
  value       = azurerm_container_app.api.ingress[0].fqdn
}

output "web_fqdn" {
  description = "Web Container App FQDN"
  value       = azurerm_container_app.web.ingress[0].fqdn
}

output "database_fqdn" {
  description = "PostgreSQL server FQDN"
  value       = azurerm_postgresql_flexible_server.main.fqdn
  sensitive   = true
}

output "resource_group_name" {
  description = "Ephemeral resource group name"
  value       = azurerm_resource_group.ephemeral.name
}

output "container_app_environment_id" {
  description = "Container App Environment ID"
  value       = azurerm_container_app_environment.main.id
}
