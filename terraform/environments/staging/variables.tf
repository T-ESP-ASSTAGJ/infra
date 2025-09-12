# =============================================================================
# STAGING ENVIRONMENT VARIABLES - CREATE NEW PROJECT FOR RESOURCES
# =============================================================================

# -----------------------------------------------------------------------------
# DIGITALOCEAN CREDENTIALS
# -----------------------------------------------------------------------------
variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}

variable "spaces_access_id" {
  description = "DigitalOcean Spaces Access Key ID (for remote state backend)"
  type        = string
  sensitive   = true
}

variable "spaces_secret_key" {
  description = "DigitalOcean Spaces Secret Access Key (for remote state backend)"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# PROJECT CONFIGURATION - CREATE NEW PROJECT
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Name of the project (will create jamly-staging-xxxxxx)"
  type        = string
  default     = "jamly"
}

variable "region" {
  description = "DigitalOcean region (must match Spaces region)"
  type        = string
  default     = "fra1"
}

variable "vpc_ip_range" {
  description = "VPC IP range"
  type        = string
  default     = "10.10.0.0/16"
}

# -----------------------------------------------------------------------------
# VM CONFIGURATION
# -----------------------------------------------------------------------------
variable "vm_count" {
  description = "Number of VMs to deploy in staging"
  type        = number
  default     = 2  # Smaller for staging

  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 10
    error_message = "VM count for staging should be between 1 and 10."
  }
}

variable "droplet_size" {
  description = "Droplet size for staging environment"
  type        = string
  default     = "s-1vcpu-2gb"

  validation {
    condition = contains([
      "s-1vcpu-1gb", "s-1vcpu-2gb", "s-2vcpu-2gb", "s-2vcpu-4gb"
    ], var.droplet_size)
    error_message = "For staging, use cost-effective droplet sizes: s-1vcpu-1gb, s-1vcpu-2gb, s-2vcpu-2gb, or s-2vcpu-4gb."
  }
}

variable "image" {
  description = "Droplet image"
  type        = string
  default     = "ubuntu-22-04-x64"
}

variable "ssh_keys" {
  description = "SSH keys ids to add to droplets"
  type        = list(number)
  default     = []
}