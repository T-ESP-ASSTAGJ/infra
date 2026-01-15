output "vm_public_ip" {
  description = "The public IP address of the VM"
  value       = azurerm_public_ip.public_ip.ip_address
}

output "admin_username" {
  description = "The admin username for SSH access"
  value       = azurerm_linux_virtual_machine.vm.admin_username
}
