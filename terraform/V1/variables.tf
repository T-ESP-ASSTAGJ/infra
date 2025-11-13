variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "rg-jamly"
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "westeurope"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "jamly"
}

variable "container_cpu" {
  description = "CPU allocation for containers (e.g., 0.25, 0.5, 1.0)"
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Memory allocation for containers (e.g., 0.5Gi, 1.0Gi)"
  type        = string
  default     = "1.0Gi"
}

variable "min_replicas" {
  description = "Minimum number of container replicas"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of container replicas"
  type        = number
  default     = 3
}

variable "db_sku_name" {
  description = "SKU for PostgreSQL Flexible Server"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "db_admin_username" {
  description = "Administrator username for PostgreSQL"
  type        = string
  default     = "psqladmin"
}

variable "db_admin_password" {
  description = "Administrator password for PostgreSQL"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "jamly"
}

variable "api_docker_image" {
  description = "Docker image for API service (from GHCR)"
  type        = string
  default     = "ghcr.io/t-esp-asstagj/api"
}

variable "api_docker_tag" {
  description = "Docker image tag for API service"
  type        = string
  default     = "staging"
}

variable "web_docker_image" {
  description = "Docker image for Web service (from GHCR)"
  type        = string
  default     = "ghcr.io/t-esp-asstagj/web"
}

variable "web_docker_tag" {
  description = "Docker image tag for Web service"
  type        = string
  default     = "staging"
}

variable "app_secret" {
  description = "Symfony APP_SECRET"
  type        = string
  sensitive   = true
}

variable "mercure_jwt_secret" {
  description = "Mercure JWT secret"
  type        = string
  default     = "tespmasstagjmercure"
  sensitive   = true
}

variable "mercure_publisher_jwt_key" {
  description = "Mercure publisher JWT key"
  type        = string
  default     = "tespmasstagjmercure"
  sensitive   = true
}

variable "mercure_subscriber_jwt_key" {
  description = "Mercure subscriber JWT key"
  type        = string
  default     = "tespmasstagjmercure"
  sensitive   = true
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}
