# =============================================================================
# MODULE VARIABLES - DIGITALOCEAN VM
# =============================================================================

# -----------------------------------------------------------------------------
# PROJECT CONFIGURATION
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Name of the project"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.project_name)) && length(var.project_name) <= 30
    error_message = "Project name must start with a letter, contain only letters, numbers, and hyphens, and be max 30 characters."
  }
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be either 'staging' or 'production'."
  }
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# INFRASTRUCTURE CONFIGURATION
# -----------------------------------------------------------------------------
variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "fra1"

  validation {
    condition = contains([
      "nyc1", "nyc2", "nyc3", "ams2", "ams3", "sfo1", "sfo2", "sfo3",
      "sgp1", "lon1", "fra1", "tor1", "blr1", "syd1"
    ], var.region)
    error_message = "Region must be a valid DigitalOcean region."
  }
}

variable "vpc_ip_range" {
  description = "IP range for the VPC (CIDR)"
  type        = string
  default     = "10.10.0.0/16"

  validation {
    condition = can(cidrhost(var.vpc_ip_range, 0)) && tonumber(split("/", var.vpc_ip_range)[1]) <= 24 && tonumber(split("/", var.vpc_ip_range)[1]) >= 16
    error_message = "VPC IP range must be a valid IPv4 CIDR block between /16 and /24."
  }
}

# -----------------------------------------------------------------------------
# VM CONFIGURATION
# -----------------------------------------------------------------------------
variable "vm_count" {
  description = "Number of VMs (Droplets) to deploy"
  type        = number
  default     = 3

  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 100
    error_message = "VM count must be between 1 and 100."
  }
}

variable "droplet_size" {
  description = "Size of the Droplets"
  type        = string
  default     = "s-1vcpu-1gb"

  validation {
    condition = contains([
      "s-1vcpu-1gb", "s-1vcpu-2gb", "s-2vcpu-2gb", "s-2vcpu-4gb",
      "s-4vcpu-8gb", "s-6vcpu-16gb", "s-8vcpu-32gb", "s-16vcpu-64gb",
      "c-2", "c-4", "c-8", "c-16", "c-32", "c-48",
      "m-2vcpu-16gb", "m-4vcpu-32gb", "m-8vcpu-64gb", "m-16vcpu-128gb"
    ], var.droplet_size)
    error_message = "Droplet size must be a valid DigitalOcean size slug."
  }
}

variable "image" {
  description = "DigitalOcean image slug or ID"
  type        = string
  default     = "ubuntu-22-04-x64"
}

variable "vm_naming_pattern" {
  description = "Pattern for VM naming (use %03d for zero-padded numbers)"
  type        = string
  default     = "vm-%03d"

  validation {
    condition     = can(regex("%[0-9]*d", var.vm_naming_pattern))
    error_message = "Naming pattern must contain a number format specifier like %d or %03d."
  }
}

# -----------------------------------------------------------------------------
# SECURITY CONFIGURATION
# -----------------------------------------------------------------------------
variable "ssh_keys" {
  description = "List of SSH key names to add to Droplets"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# FEATURES CONFIGURATION
# -----------------------------------------------------------------------------

variable "enable_ipv6" {
  description = "Enable IPv6 for Droplets"
  type        = bool
  default     = false
}

variable "enable_backups" {
  description = "Enable automated backups"
  type        = bool
  default     = false
}