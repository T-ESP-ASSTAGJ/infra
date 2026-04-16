# ── Inputs from the persistent layer (passed by CI/CD or -var flags) ─────────

variable "vm_subnet_id" {
  description = "ID of the VM subnet created by the persistent layer"
  type        = string
}

variable "persistent_resource_group_name" {
  description = "Name of the persistent resource group — used to reference the existing VM subnet NSG"
  type        = string
}

variable "appgw_backend_pool_id" {
  description = "ID of the Application Gateway default backend pool — worker NIC is registered here"
  type        = string
}

# ── Common ─────────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "jamly"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "swedencentral"
}

variable "tags" {
  description = "Extra tags merged onto all resources"
  type        = map(string)
  default     = {}
}

# ── VM configuration ──────────────────────────────────────────────────────────

variable "admin_username" {
  description = "Admin username for both VMs (used in Ansible inventory)"
  type        = string
  default     = "tfou3lik"
}

variable "ssh_public_key" {
  description = "SSH public key content for VM access"
  type        = string
  sensitive   = true
}

variable "vm_size_control_plane" {
  description = "Azure VM size for the Kubernetes control plane"
  type        = string
  default     = "Standard_B4s_v2"
}

variable "vm_size_worker" {
  description = "Azure VM size for the Kubernetes worker node (~€27/month for Standard_B2ls_v2)"
  type        = string
  default     = "Standard_B2ls_v2"
}

variable "db_admin_login" {
  description = "Database username"
  type        = string
  sensitive   = false
}
variable "db_admin_password" {
  description = "Database password"
  type        = string
  sensitive   = false
}
variable "db_name" {
  description = "Database name"
  type        = string
  sensitive   = false
}

variable "eso_identity_id" {
  description = "Resource ID of the ESO managed identity (from persistent outputs)"
  type        = string
}

variable "eso_identity_client_id" {
  description = "Client ID of the ESO managed identity (from persistent outputs)"
  type        = string
}

variable "eso_keyvault_url" {
  description = "Vault URI of the Key Vault (from persistent outputs)"
  type        = string
}

variable "db_subnet_id" {
  description = "ID of the delegated DB subnet (from persistent outputs)"
  type        = string
}

variable "private_dns_zone_postgres_id" {
  description = "ID of the PostgreSQL private DNS zone (from persistent outputs)"
  type        = string
}
