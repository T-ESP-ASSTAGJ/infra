# =============================================================================
# STAGING ENVIRONMENT VARIABLES
# =============================================================================

variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "jamly"
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "fra1"
}

variable "vpc_ip_range" {
  description = "VPC IP range"
  type        = string
  default     = "10.10.0.0/16"
}

variable "vm_count" {
  description = "Number of VMs to deploy"
  type        = number
  default     = 2  # Smaller for staging
}

variable "droplet_size" {
  description = "Droplet size"
  type        = string
  default     = "s-1vcpu-2gb"  # Smaller for staging
}

variable "image" {
  description = "Droplet image"
  type        = string
  default     = "ubuntu-22-04-x64"
}

variable "ssh_keys" {
  description = "SSH keys to add to droplets"
  type        = list(string)
  default     = []
}

variable "allowed_ssh_cidrs" {
  description = "Allowed SSH CIDR blocks"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_http_cidrs" {
  description = "Allowed HTTP CIDR blocks"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "enable_monitoring" {
  description = "Enable monitoring"
  type        = bool
  default     = false  # Disabled for staging
}

variable "tags" {
  description = "Additional tags"
  type        = list(string)
  default     = ["staging"]
}

variable "user_data" {
  description = "Custom user data"
  type        = string
  default     = ""
}