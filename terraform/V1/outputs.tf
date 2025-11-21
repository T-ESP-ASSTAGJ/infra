output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Azure region where resources are deployed"
  value       = azurerm_resource_group.main.location
}

output "api_url" {
  description = "URL of the API application"
  value       = "https://${azurerm_container_app.api.latest_revision_fqdn}"
}

output "api_fqdn" {
  description = "FQDN of the API Container App"
  value       = azurerm_container_app.api.latest_revision_fqdn
}

output "web_url" {
  description = "URL of the Web application"
  value       = "https://${azurerm_container_app.web.latest_revision_fqdn}"
}

output "web_fqdn" {
  description = "FQDN of the Web Container App"
  value       = azurerm_container_app.web.latest_revision_fqdn
}

output "api_app_name" {
  description = "Name of the API Container App"
  value       = azurerm_container_app.api.name
}

output "web_app_name" {
  description = "Name of the Web Container App"
  value       = azurerm_container_app.web.name
}

output "container_app_environment_name" {
  description = "Name of the Container Apps Environment"
  value       = azurerm_container_app_environment.main.name
}

output "postgresql_server_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgresql_database_name" {
  description = "Name of the PostgreSQL database"
  value       = azurerm_postgresql_flexible_server_database.main.name
}

output "mercure_url" {
  description = "Mercure URL endpoint"
  value       = "https://${local.api_fqdn}/.well-known/mercure"
}
