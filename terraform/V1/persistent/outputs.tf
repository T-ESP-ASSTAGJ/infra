output "application_gateway_id" {
  description = "Application Gateway ID for ephemeral infrastructure to reference"
  value       = azurerm_application_gateway.main.id
}

output "application_gateway_name" {
  description = "Application Gateway name"
  value       = azurerm_application_gateway.main.name
}

output "web_backend_pool_name" {
  description = "Web backend pool name"
  value       = "web-backend-pool"
}

output "api_backend_pool_name" {
  description = "API backend pool name"
  value       = "api-backend-pool"
}

output "resource_group_name" {
  description = "Persistent resource group name"
  value       = azurerm_resource_group.persistent.name
}

output "public_ip_address" {
  description = "Application Gateway public IP address"
  value       = azurerm_public_ip.gateway.ip_address
}

output "public_ip_fqdn" {
  description = "Application Gateway public IP FQDN"
  value       = azurerm_public_ip.gateway.fqdn
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.main.name
}

output "container_apps_subnet_id" {
  description = "Container Apps subnet ID"
  value       = azurerm_subnet.container_apps.id
}

output "dns_records" {
  description = "Cloudflare DNS records created"
  value = {
    web = var.custom_domain != "" && var.cloudflare_zone_id != "" ? {
      name    = cloudflare_record.web[0].hostname
      type    = cloudflare_record.web[0].type
      content = cloudflare_record.web[0].content
    } : null
    api = var.custom_domain_api != "" && var.cloudflare_zone_id != "" ? {
      name    = cloudflare_record.api[0].hostname
      type    = cloudflare_record.api[0].type
      content = cloudflare_record.api[0].content
    } : null
  }
}
