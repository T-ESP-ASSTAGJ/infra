# =============================================================================
# STAGING ENVIRONMENT VARIABLES
# =============================================================================

variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
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