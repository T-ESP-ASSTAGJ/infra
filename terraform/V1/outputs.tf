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

output "custom_domain_web" {
  description = "Custom domain configured for web application"
  value       = var.custom_domain != "" ? var.custom_domain : "Not configured"
}

output "custom_domain_api" {
  description = "Custom domain configured for API application"
  value       = var.custom_domain_api != "" ? var.custom_domain_api : "Not configured"
}

output "web_custom_domain_validation" {
  description = "Validation token for web custom domain"
  value       = var.custom_domain != "" ? azurerm_container_app_custom_domain.web[0].container_app_environment_certificate_id : "N/A"
}

output "api_custom_domain_validation" {
  description = "Validation token for API custom domain"
  value       = var.custom_domain_api != "" ? azurerm_container_app_custom_domain.api[0].container_app_environment_certificate_id : "N/A"
}

output "cloudflare_dns_record_web" {
  description = "Cloudflare DNS record configuration for web"
  value = var.custom_domain != "" && var.cloudflare_zone_id != "" ? {
    name    = cloudflare_record.web[0].name
    content = cloudflare_record.web[0].content
    proxied = cloudflare_record.web[0].proxied
  } : null
}

output "cloudflare_dns_record_api" {
  description = "Cloudflare DNS record configuration for API"
  value = var.custom_domain_api != "" && var.cloudflare_zone_id != "" ? {
    name    = cloudflare_record.api[0].name
    content = cloudflare_record.api[0].content
    proxied = cloudflare_record.api[0].proxied
  } : null
}

output "cloudflare_validation_record_web" {
  description = "Cloudflare TXT record for Azure web domain validation"
  value = var.custom_domain != "" && var.cloudflare_zone_id != "" ? {
    name    = cloudflare_record.web_validation[0].name
    content = cloudflare_record.web_validation[0].content
  } : null
  sensitive = true
}

output "cloudflare_validation_record_api" {
  description = "Cloudflare TXT record for Azure API domain validation"
  value = var.custom_domain_api != "" && var.cloudflare_zone_id != "" ? {
    name    = cloudflare_record.api_validation[0].name
    content = cloudflare_record.api_validation[0].content
  } : null
  sensitive = true
}
