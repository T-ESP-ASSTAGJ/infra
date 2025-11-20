output "api_vm_name" {
  description = "Name of the API VM"
  value       = azurerm_linux_virtual_machine.api.name
}

output "api_public_ip" {
  description = "Public IP of the API VM"
  value       = azurerm_public_ip.api.ip_address
}

output "api_private_ip" {
  description = "Private IP of the API VM"
  value       = azurerm_network_interface.api.private_ip_address
}

output "api_ssh_connection" {
  description = "SSH connection string for API VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.api.ip_address}"
}

# Web VM
output "web_vm_name" {
  description = "Name of the Web VM"
  value       = azurerm_linux_virtual_machine.web.name
}

output "web_public_ip" {
  description = "Public IP of the Web VM"
  value       = azurerm_public_ip.web.ip_address
}

output "web_private_ip" {
  description = "Private IP of the Web VM"
  value       = azurerm_network_interface.web.private_ip_address
}

output "web_ssh_connection" {
  description = "SSH connection string for Web VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.web.ip_address}"
}

# Database VM
output "database_vm_name" {
  description = "Name of the Database VM"
  value       = azurerm_linux_virtual_machine.database.name
}

output "database_public_ip" {
  description = "Public IP of the Database VM"
  value       = azurerm_public_ip.database.ip_address
}

output "database_private_ip" {
  description = "Private IP of the Database VM"
  value       = azurerm_network_interface.database.private_ip_address
}

output "database_ssh_connection" {
  description = "SSH connection string for Database VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.database.ip_address}"
}

# General
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Azure region"
  value       = azurerm_resource_group.main.location
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}