# =============================================================================
# STAGING ENVIRONMENT CONFIGURATION - CREATE NEW PROJECT FOR RESOURCES
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
}

# Provider configuration
provider "digitalocean" {
  token = var.do_token
  spaces_access_id  = var.spaces_access_id
  spaces_secret_key = var.spaces_secret_key
}

module "digitalocean_vm" {
  source = "../../modules/digitalocean-vm"

  # Project configuration
  project_name  = var.project_name
  environment   = "staging"

  # Infrastructure settings
  region        = var.region
  vpc_ip_range  = var.vpc_ip_range

  # VM configuration
  vm_count      = var.vm_count
  droplet_size  = var.droplet_size
  image         = var.image

  # Security
  ssh_keys      = var.ssh_keys

  # Features (staging-specific defaults)
  enable_backups = false  # Disabled for staging to save costs
}

# Local variables for staging-specific configuration
locals {
  environment = "staging"
}