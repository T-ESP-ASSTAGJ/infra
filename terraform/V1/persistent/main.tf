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
      Layer       = "persistent"
    }
  )
  name_prefix = "${var.project_name}-${local.environment}"
}

# Persistent Resource Group (for networking)
resource "azurerm_resource_group" "persistent" {
  name     = "${var.project_name}-${local.environment}-persistent-rg"
  location = var.location
  tags     = local.common_tags
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "gateway" {
  name                = "${local.name_prefix}-appgw-pip"
  resource_group_name = azurerm_resource_group.persistent.name
  location            = azurerm_resource_group.persistent.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.name_prefix}-appgw"
  tags                = local.common_tags
}

# Virtual Network for Application Gateway
resource "azurerm_virtual_network" "main" {
  name                = "${local.name_prefix}-vnet"
  resource_group_name = azurerm_resource_group.persistent.name
  location            = azurerm_resource_group.persistent.location
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

# Subnet for Application Gateway (requires /24 minimum)
resource "azurerm_subnet" "gateway" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.persistent.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Subnet for Container Apps Environment (requires /23 minimum for production)
resource "azurerm_subnet" "container_apps" {
  name                 = "container-apps-subnet"
  resource_group_name  = azurerm_resource_group.persistent.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/23"]

  lifecycle {
    ignore_changes = [
      delegation
    ]
  }
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = "${local.name_prefix}-appgw"
  resource_group_name = azurerm_resource_group.persistent.name
  location            = azurerm_resource_group.persistent.location
  tags                = local.common_tags

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.gateway.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.gateway.id
  }

  # Backend pools (initially empty, will be populated by ephemeral infrastructure)
  backend_address_pool {
    name = "web-backend-pool"
  }

  backend_address_pool {
    name = "api-backend-pool"
  }

  # Backend HTTP settings
  backend_http_settings {
    name                  = "web-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 3000
    protocol              = "Http"
    request_timeout       = 60
  }

  backend_http_settings {
    name                  = "api-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  # HTTP Listeners
  http_listener {
    name                           = "web-http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
    host_name                      = var.custom_domain
  }

  http_listener {
    name                           = "api-http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
    host_name                      = var.custom_domain_api
  }

  # Request routing rules
  request_routing_rule {
    name                       = "web-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "web-http-listener"
    backend_address_pool_name  = "web-backend-pool"
    backend_http_settings_name = "web-http-settings"
    priority                   = 100
  }

  request_routing_rule {
    name                       = "api-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "api-http-listener"
    backend_address_pool_name  = "api-backend-pool"
    backend_http_settings_name = "api-http-settings"
    priority                   = 200
  }

  lifecycle {
    ignore_changes = [
      # Allow ephemeral infrastructure to modify backend pools
      backend_address_pool
    ]
  }
}

# Cloudflare DNS Records (pointing to the static Application Gateway IP)
resource "cloudflare_record" "web" {
  count   = var.custom_domain != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = local.environment == "production" ? "@" : local.environment
  content = azurerm_public_ip.gateway.ip_address
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Managed by Terraform (persistent) - web ${local.environment} environment"
}

resource "cloudflare_record" "api" {
  count   = var.custom_domain_api != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(var.custom_domain_api, ".jamly.eu")
  content = azurerm_public_ip.gateway.ip_address
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Managed by Terraform (persistent) - API ${local.environment} environment"
}
