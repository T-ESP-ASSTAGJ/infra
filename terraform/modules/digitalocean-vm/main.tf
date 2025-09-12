# =============================================================================
# DIGITALOCEAN VM MODULE - MAIN CONFIGURATION
# =============================================================================

# -----------------------------------------------------------------------------
# TERRAFORM CONFIGURATION
# -----------------------------------------------------------------------------
terraform {
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

# -----------------------------------------------------------------------------
# DATA SOURCES
# -----------------------------------------------------------------------------
data "digitalocean_ssh_keys" "existing" {
  count = length(var.ssh_keys) > 0 ? 1 : 0

  filter {
    key    = "name"
    values = var.ssh_keys
  }
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# -----------------------------------------------------------------------------
# PROJECT RESOURCE
# -----------------------------------------------------------------------------
resource "digitalocean_project" "main" {
  name        = "${var.project_name}-${var.environment}-${random_string.suffix.result}"
  description = "VM deployment for ${var.project_name} - ${var.environment}"
  purpose     = "Web Application"
  environment = title(var.environment)

  resources = digitalocean_droplet.vm[*].urn
}

# -----------------------------------------------------------------------------
# NETWORK RESOURCES
# -----------------------------------------------------------------------------
resource "digitalocean_vpc" "main" {
  name     = "${var.project_name}-${var.environment}-vpc-${random_string.suffix.result}"
  region   = var.region
  ip_range = var.vpc_ip_range

  description = "VPC for ${var.project_name} ${var.environment} environment"
}

# -----------------------------------------------------------------------------
# TAGS
# -----------------------------------------------------------------------------
resource "digitalocean_tag" "project_tag" {
  name = var.project_name
}

resource "digitalocean_tag" "environment_tag" {
  name = var.environment
}

# -----------------------------------------------------------------------------
# VIRTUAL MACHINES (DROPLETS)
# -----------------------------------------------------------------------------
resource "digitalocean_droplet" "vm" {
  count = var.vm_count

  name   = format("${var.project_name}-${var.environment}-${var.vm_naming_pattern}", count.index + 1)
  image  = var.image
  region = var.region
  size   = var.droplet_size

  # Network configuration
  vpc_uuid = digitalocean_vpc.main.id
  ipv6     = var.enable_ipv6

  # SSH keys
  ssh_keys = var.ssh_keys

  # Features
  backups    = var.enable_backups

  # Tags
  tags = concat([
    digitalocean_tag.project_tag.id,
    digitalocean_tag.environment_tag.id
  ], var.tags)

  lifecycle {
    prevent_destroy = false
  }
}