# =============================================================================
# STAGING ENVIRONMENT CONFIGURATION
# =============================================================================

terraform {
  required_version = ">= 1.6"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.34"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  # Using local backend (default)
  # Add remote backend later when needed
}

# Provider configuration
provider "digitalocean" {
  token = var.do_token
}

# Call the VM module
module "digitalocean_vm" {
  source = "../../modules/digitalocean-vm"

  # Project configuration
  project_name = var.project_name
  environment  = "staging"

  # Infrastructure settings
  region        = var.region
  vpc_ip_range  = var.vpc_ip_range

  # VM configuration
  vm_count      = var.vm_count
  droplet_size  = var.droplet_size
  image         = var.image

  # Security
  ssh_keys           = var.ssh_keys

  # Features (staging-specific defaults)
  enable_backups    = false  # Disabled for staging
}

# Local variables for staging-specific configuration
locals {
  environment = "staging"
}