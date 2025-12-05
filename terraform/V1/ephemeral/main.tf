terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  environment = terraform.workspace
  common_tags = merge(
    var.tags,
    {
      Environment = local.environment
      Project     = var.project_name
      Layer       = "ephemeral"
    }
  )
  name_prefix = "${var.project_name}-${local.environment}"
}

# Data source to reference persistent infrastructure
data "azurerm_resource_group" "persistent" {
  name = var.persistent_resource_group_name
}

data "azurerm_application_gateway" "main" {
  name                = var.application_gateway_name
  resource_group_name = data.azurerm_resource_group.persistent.name
}

# Ephemeral Resource Group (for containers and database)
resource "azurerm_resource_group" "ephemeral" {
  name     = "${var.project_name}-${local.environment}-ephemeral-rg"
  location = var.location
  tags     = local.common_tags
}

# Log Analytics Workspace for Container Apps
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-logs"
  location            = azurerm_resource_group.ephemeral.location
  resource_group_name = azurerm_resource_group.ephemeral.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# Container Apps Environment with VNet integration
resource "azurerm_container_app_environment" "main" {
  name                       = "${local.name_prefix}-env"
  location                   = azurerm_resource_group.ephemeral.location
  resource_group_name        = azurerm_resource_group.ephemeral.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = local.common_tags
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${local.name_prefix}-psql"
  resource_group_name    = azurerm_resource_group.ephemeral.name
  location               = azurerm_resource_group.ephemeral.location
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
  resource_group_name          = azurerm_resource_group.ephemeral.name
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
        value = "https://${var.custom_domain_api}/.well-known/mercure"
      }

      env {
        name  = "MERCURE_PUBLIC_URL"
        value = "https://${var.custom_domain_api}/.well-known/mercure"
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

# Web Container App (Next.js)
resource "azurerm_container_app" "web" {
  name                         = "${local.name_prefix}-web"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.ephemeral.name
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
        value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
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

# Update Application Gateway backend pools with container FQDNs
resource "null_resource" "update_appgw_backends" {
  triggers = {
    api_fqdn       = azurerm_container_app.api.ingress[0].fqdn
    web_fqdn       = azurerm_container_app.web.ingress[0].fqdn
    gateway_name   = var.application_gateway_name
    persistent_rg  = var.persistent_resource_group_name
    api_pool_name  = var.api_backend_pool_name
    web_pool_name  = var.web_backend_pool_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Update API backend pool
      az network application-gateway address-pool update \
        --gateway-name ${var.application_gateway_name} \
        --resource-group ${var.persistent_resource_group_name} \
        --name ${var.api_backend_pool_name} \
        --servers ${azurerm_container_app.api.ingress[0].fqdn}

      # Update Web backend pool
      az network application-gateway address-pool update \
        --gateway-name ${var.application_gateway_name} \
        --resource-group ${var.persistent_resource_group_name} \
        --name ${var.web_backend_pool_name} \
        --servers ${azurerm_container_app.web.ingress[0].fqdn}

      echo "Backend pools updated successfully!"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Clear API backend pool
      az network application-gateway address-pool update \
        --gateway-name ${self.triggers.gateway_name} \
        --resource-group ${self.triggers.persistent_rg} \
        --name ${self.triggers.api_pool_name} \
        --servers "" || true

      # Clear Web backend pool
      az network application-gateway address-pool update \
        --gateway-name ${self.triggers.gateway_name} \
        --resource-group ${self.triggers.persistent_rg} \
        --name ${self.triggers.web_pool_name} \
        --servers "" || true

      echo "Backend pools cleared!"
    EOT
  }

  depends_on = [
    azurerm_container_app.api,
    azurerm_container_app.web
  ]
}
