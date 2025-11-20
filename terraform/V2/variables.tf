variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "rg-docker-app"
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "westeurope"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "dockerapp"
}

variable "vm_size" {
  description = "Size of the Azure VM"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key for VM access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vm_os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 30
}

variable "allowed_ssh_ips" {
  description = "List of IP addresses allowed to SSH into the VM"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "docker_image" {
  description = "Docker image to deploy (from GHCR)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}

variable "subscription_id" {
  description = "Azure subscription_id"
  type        = string
  default     = ""
}

variable "vm_size_database" {
  description = "Size of the database VM"
  type        = string
  default     = "Standard_B1s"
}

variable "vm_os_disk_size_gb_database" {
  description = "Size of the database OS disk in GB"
  type        = number
  default     = 30
}
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

variable "mercure_publisher_jwt_key" {
  description = "Mercure publisher JWT key"
  type        = string
  sensitive   = true
}

variable "mercure_subscriber_jwt_key" {
  description = "Mercure subscriber JWT key"
  type        = string
  sensitive   = true
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