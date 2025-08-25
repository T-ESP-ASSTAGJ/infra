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
# SECURITY RESOURCES
# -----------------------------------------------------------------------------
resource "digitalocean_firewall" "main" {
  count = var.enable_firewall ? 1 : 0

  name = "${var.project_name}-${var.environment}-fw-${random_string.suffix.result}"

  # SSH access
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.allowed_ssh_cidrs
  }

  # HTTP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = var.allowed_http_cidrs
  }

  # HTTPS
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = var.allowed_http_cidrs
  }

  # Additional ports
  dynamic "inbound_rule" {
    for_each = var.additional_ports
    content {
      protocol         = "tcp"
      port_range       = tostring(inbound_rule.value)
      source_addresses = var.allowed_http_cidrs
    }
  }

  # Internal communication
  inbound_rule {
    protocol    = "tcp"
    port_range  = "1-65535"
    source_tags = [digitalocean_tag.vm_tag.id]
  }

  inbound_rule {
    protocol    = "udp"
    port_range  = "1-65535"
    source_tags = [digitalocean_tag.vm_tag.id]
  }

  inbound_rule {
    protocol    = "icmp"
    source_tags = [digitalocean_tag.vm_tag.id]
  }

  # Outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  droplet_ids = digitalocean_droplet.vm[*].id
}

# -----------------------------------------------------------------------------
# TAGS
# -----------------------------------------------------------------------------
resource "digitalocean_tag" "project_tag" {
  name = "${var.project_name}-${var.environment}"
}

resource "digitalocean_tag" "vm_tag" {
  name = "${var.project_name}-${var.environment}-vm"
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
  ssh_keys = length(var.ssh_keys) > 0 ? data.digitalocean_ssh_keys.existing[0].ssh_keys[*].id : []

  # Features
  monitoring = var.enable_monitoring
  backups    = var.enable_backups

  # User data
  user_data = var.user_data != "" ? var.user_data : (var.user_data_file != "" ? file(var.user_data_file) : local.default_user_data)

  # Tags
  tags = concat([
    digitalocean_tag.project_tag.id,
    digitalocean_tag.vm_tag.id,
    digitalocean_tag.environment_tag.id
  ], var.tags)

  lifecycle {
    prevent_destroy = false
  }
}