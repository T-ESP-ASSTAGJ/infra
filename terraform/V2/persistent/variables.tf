variable "ssh_source_address" {
  description = "CIDR or IP allowed to SSH into VMs. Restrict to your office/VPN IP in production."
  type        = string
  default     = "*"
}

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
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "custom_domain" {
  description = "Custom domain for web application"
  type        = string
}

variable "custom_domain_api" {
  description = "Custom domain for API"
  type        = string
}

variable "custom_domain_argocd" {
  description = "Custom domain for ArgoCD UI"
  type        = string
  default     = ""
}

variable "web_ssl_cert_secret_id" {
  description = "Key Vault secret ID for web SSL certificate"
  type        = string
  default     = ""
}

variable "api_ssl_cert_secret_id" {
  description = "Key Vault secret ID for API SSL certificate"
  type        = string
  default     = ""
}