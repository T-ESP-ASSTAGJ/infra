variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "jamly"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "francecentral"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# References to persistent infrastructure
variable "persistent_resource_group_name" {
  description = "Name of the persistent resource group (from persistent terraform outputs)"
  type        = string
}

variable "application_gateway_name" {
  description = "Name of the Application Gateway (from persistent terraform outputs)"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Virtual Network (from persistent terraform outputs)"
  type        = string
}

variable "container_apps_subnet_id" {
  description = "ID of the Container Apps subnet (from persistent terraform outputs)"
  type        = string
}

variable "web_backend_pool_name" {
  description = "Web backend pool name in Application Gateway"
  type        = string
  default     = "web-backend-pool"
}

variable "api_backend_pool_name" {
  description = "API backend pool name in Application Gateway"
  type        = string
  default     = "api-backend-pool"
}

variable "custom_domain_api" {
  description = "Custom domain for API (used in env vars)"
  type        = string
}

# Container configuration
variable "api_docker_image" {
  description = "Docker image for API"
  type        = string
}

variable "api_docker_tag" {
  description = "Docker tag for API"
  type        = string
}

variable "web_docker_image" {
  description = "Docker image for Web"
  type        = string
}

variable "web_docker_tag" {
  description = "Docker tag for Web"
  type        = string
}

variable "container_cpu" {
  description = "CPU allocation for containers"
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Memory allocation for containers"
  type        = string
  default     = "1.0Gi"
}

variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 3
}

# Database configuration
variable "db_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  sensitive   = true
}

variable "db_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "jamly"
}

variable "db_sku_name" {
  description = "PostgreSQL SKU name"
  type        = string
}

# Application secrets
variable "app_secret" {
  description = "Symfony APP_SECRET"
  type        = string
  sensitive   = true
}

variable "mercure_jwt_secret" {
  description = "Mercure JWT secret"
  type        = string
  sensitive   = true
}

# Cloudflare secrets
variable "cloudflare_api_token" {
  description = "Cloudflare api token"
  type = string
  sensitive = true 
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone id token"
  type = string
  sensitive = true 
}
