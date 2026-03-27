output "resource_group_name" {
  description = "Name of the persistent resource group"
  value       = azurerm_resource_group.rg.name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.vnet.id
}

output "vm_subnet_id" {
  description = "ID of the VM subnet — pass this to the ephemeral layer"
  value       = azurerm_subnet.subnet.id
}

output "appgw_subnet_id" {
  description = "ID of the Application Gateway subnet"
  value       = azurerm_subnet.appgw_subnet.id
}

output "appgw_public_ip" {
  description = "Static public IP address of the Application Gateway"
  value       = azurerm_public_ip.gateway.ip_address
}

output "appgw_id" {
  description = "ID of the Application Gateway"
  value       = azurerm_application_gateway.appgw.id
}

output "appgw_backend_pool_id" {
  description = "ID of the default backend address pool — register VM NICs here from the ephemeral layer"
  value       = tolist(azurerm_application_gateway.appgw.backend_address_pool)[0].id
}

output "key_vault_uri" {
  description = "URI of the Key Vault (for certificate retrieval)"
  value       = azurerm_key_vault.certs.vault_uri
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.certs.id
}

output "appgw_identity_id" {
  description = "ID of the App Gateway managed identity — use for additional Key Vault access policies"
  value       = azurerm_user_assigned_identity.appgw.id
}
