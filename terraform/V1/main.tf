terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  environment = terraform.workspace

  common_tags = merge(
    var.tags,
    {
      Environment = local.environment
      Project     = var.project_name
    }
  )

  name_prefix = "${var.project_name}-${local.environment}"

  # Compute the API FQDN based on Azure Container Apps naming pattern
  api_fqdn = "${local.name_prefix}-api.${azurerm_container_app_environment.main.default_domain}"
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# Log Analytics Workspace for Container Apps
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                       = "${local.name_prefix}-env"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = local.common_tags
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${local.name_prefix}-psql"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "16"
  administrator_login    = var.db_admin_username
  administrator_password = var.db_admin_password
  storage_mb             = 32768
  sku_name               = var.db_sku_name
  zone                   = "1"
  tags                   = local.common_tags
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# PostgreSQL Firewall Rule - Allow Azure Services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# API Container App (Symfony/FrankenPHP)
resource "azurerm_container_app" "api" {
  name                         = "${local.name_prefix}-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.common_tags

  template {
    container {
      name   = "api"
      image  = "${var.api_docker_image}:${var.api_docker_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name  = "APP_ENV"
        value = local.environment
      }

      env {
        name  = "APP_SECRET"
        value = var.app_secret
      }

      env {
        name  = "MERCURE_JWT_SECRET"
        value = var.mercure_jwt_secret
      }

      env {
        name  = "MERCURE_URL"
        value = "https://${local.api_fqdn}/.well-known/mercure"
      }

      env {
        name = "MERCURE_PUBLIC_URL"
        value = "https://${var.custom_domain}/.well-known/mercure"
      }

      env {
        name  = "DATABASE_URL"
        value = "postgresql://${var.db_admin_username}:${var.db_admin_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${var.db_name}?sslmode=require"
      }
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

# Cloudflare TXT Record for Azure Domain Validation - Web
resource "cloudflare_record" "web_validation" {
  count   = var.custom_domain != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = local.environment == "production" ? "asuid" : "asuid.${local.environment}"
  content = azurerm_container_app.web.custom_domain_verification_id
  type    = "TXT"
  ttl     = 3600

  comment = "Azure domain validation for web - ${local.environment}"
}

# Cloudflare CNAME Record for Web Custom Domain
resource "cloudflare_record" "web" {
  count   = var.custom_domain != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = local.environment == "production" ? "@" : local.environment
  content = azurerm_container_app.web.latest_revision_fqdn
  type    = "CNAME"
  ttl     = 1
  proxied = false

  comment = "Managed by Terraform - web ${local.environment} environment"
}

# Cloudflare TXT Record for Azure Domain Validation - API
resource "cloudflare_record" "api_validation" {
  count   = var.custom_domain_api != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "asuid.${trimsuffix(var.custom_domain_api, ".jamly.eu")}"
  content = azurerm_container_app.api.custom_domain_verification_id
  type    = "TXT"
  ttl     = 300

  comment = "Azure domain validation for API - ${local.environment}"
}

# Cloudflare CNAME Record for API Custom Domain
resource "cloudflare_record" "api" {
  count   = var.custom_domain_api != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(var.custom_domain_api, ".jamly.eu")
  content = azurerm_container_app.api.latest_revision_fqdn
  type    = "CNAME"
  ttl     = 300
  proxied = false

  comment = "Managed by Terraform - API ${local.environment} environment"
}

# DNS validation check for web domain - polls until TXT record is resolvable
resource "null_resource" "wait_for_web_dns" {
  count = var.custom_domain != "" && var.cloudflare_zone_id != "" ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for web TXT record to propagate..."
      for i in {1..30}; do
        if dig +short TXT ${cloudflare_record.web_validation[0].hostname} | grep -q "${azurerm_container_app.web.custom_domain_verification_id}"; then
          echo "Web TXT record validated!"
          exit 0
        fi
        echo "Attempt $i/30: TXT record not yet propagated, waiting 10s..."
        sleep 10
      done
      echo "Warning: TXT record validation timed out after 5 minutes"
      exit 0
    EOT
  }

  depends_on = [
    cloudflare_record.web_validation,
    cloudflare_record.web
  ]
}

# DNS validation check for API domain - polls until TXT record is resolvable
resource "null_resource" "wait_for_api_dns" {
  count = var.custom_domain_api != "" && var.cloudflare_zone_id != "" ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for API TXT record to propagate..."
      for i in {1..30}; do
        if dig +short TXT ${cloudflare_record.api_validation[0].hostname} | grep -q "${azurerm_container_app.api.custom_domain_verification_id}"; then
          echo "API TXT record validated!"
          exit 0
        fi
        echo "Attempt $i/30: TXT record not yet propagated, waiting 10s..."
        sleep 10
      done
      echo "Warning: TXT record validation timed out after 5 minutes"
      exit 0
    EOT
  }

  depends_on = [
    cloudflare_record.api_validation,
    cloudflare_record.api
  ]
}

# Managed Certificate for Web Custom Domain
resource "azurerm_container_app_custom_domain" "web" {
  count                    = var.custom_domain != "" ? 1 : 0
  name                     = var.custom_domain
  container_app_id         = azurerm_container_app.web.id
  certificate_binding_type = "SniEnabled"

  depends_on = [
    azurerm_container_app.web,
    cloudflare_record.web,
    cloudflare_record.web_validation,
    null_resource.wait_for_web_dns
  ]
}

# Managed Certificate for API Custom Domain
resource "azurerm_container_app_custom_domain" "api" {
  count                    = var.custom_domain_api != "" ? 1 : 0
  name                     = var.custom_domain_api
  container_app_id         = azurerm_container_app.api.id
  certificate_binding_type = "SniEnabled"

  depends_on = [
    azurerm_container_app.api,
    cloudflare_record.api,
    cloudflare_record.api_validation,
    null_resource.wait_for_api_dns
  ]
}

# Web Container App (Next.js)
resource "azurerm_container_app" "web" {
  name                         = "${local.name_prefix}-web"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.common_tags

  template {
    container {
      name   = "web"
      image  = "${var.web_docker_image}:${var.web_docker_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name  = "NODE_ENV"
        value = local.environment
      }

      env {
        name  = "API_URL"
        value = "https://${azurerm_container_app.api.latest_revision_fqdn}"
      }
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
  }

  ingress {
    external_enabled = true
    target_port      = 3000
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}
