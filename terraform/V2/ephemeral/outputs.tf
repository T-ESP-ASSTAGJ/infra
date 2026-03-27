output "control_plane_public_ip" {
  description = "Public IP of the control plane VM — use as Ansible SSH entry point"
  value       = azurerm_public_ip.control_plane.ip_address
}

output "control_plane_private_ip" {
  description = "Private IP of the control plane VM — advertised as the K8s API server address"
  value       = azurerm_network_interface.control_plane.private_ip_address
}

output "worker_private_ip" {
  description = "Private IP of the worker VM — reached via ProxyJump through the control plane"
  value       = azurerm_network_interface.worker.private_ip_address
}
