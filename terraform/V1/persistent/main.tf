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

# Managed Identity for Application Gateway to access Key Vault
resource "azurerm_user_assigned_identity" "appgw" {
  name                = "${local.name_prefix}-appgw-identity"
  resource_group_name = azurerm_resource_group.persistent.name
  location            = azurerm_resource_group.persistent.location
  tags                = local.common_tags
}

# Key Vault for SSL certificates
resource "azurerm_key_vault" "certs" {
  name                       = "${var.project_name}-${local.environment}-kv"
  location                   = azurerm_resource_group.persistent.location
  resource_group_name        = azurerm_resource_group.persistent.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.common_tags

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.appgw.principal_id

    secret_permissions = [
      "Get",
      "List"
    ]

    certificate_permissions = [
      "Get",
      "List"
    ]
  }

  # Access policy for Terraform/deployment principal
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
      "Recover"
    ]

    certificate_permissions = [
      "Get",
      "List",
      "Create",
      "Import",
      "Delete",
      "Purge",
      "Recover",
      "Update"
    ]
  }
}

# Data source for current client config
data "azurerm_client_config" "current" {}

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

  # Identity for accessing Key Vault
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw.id]
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

  # Cloudflare Origin SSL certificate for Application Gateway
  # This allows Cloudflare to connect via HTTPS in "Full" mode with a trusted certificate
  ssl_certificate {
    name     = "cloudflare-origin-cert"
    data     = filebase64("${path.module}/cloudflare-origin.pfx")

    password = ""
  }

  # SSL Certificates from Key Vault (optional, for direct HTTPS access without Cloudflare)
  dynamic "ssl_certificate" {
    for_each = var.web_ssl_cert_secret_id != "" ? [1] : []
    content {
      name                = "web-ssl-cert"
      key_vault_secret_id = var.web_ssl_cert_secret_id
    }
  }

  dynamic "ssl_certificate" {
    for_each = var.api_ssl_cert_secret_id != "" ? [1] : []
    content {
      name                = "api-ssl-cert"
      key_vault_secret_id = var.api_ssl_cert_secret_id
    }
  }

  # Backend pools (initially empty, will be populated by ephemeral infrastructure)
  backend_address_pool {
    name = "web-backend-pool"
  }

  backend_address_pool {
    name = "api-backend-pool"
  }

  # Health probes
  probe {
    name                                      = "web-health-probe"
    protocol                                  = "Https"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  probe {
    name                                      = "api-health-probe"
    protocol                                  = "Https"
    path                                      = "/api/docs"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  # Backend HTTP settings
  backend_http_settings {
    name                                = "web-http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    pick_host_name_from_backend_address = true
    probe_name                          = "web-health-probe"
  }

  backend_http_settings {
    name                                = "api-http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    pick_host_name_from_backend_address = true
    probe_name                          = "api-health-probe"
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

  # HTTPS Listeners (using Cloudflare Origin cert for "Full" SSL mode)
  http_listener {
    name                           = "web-https-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    host_name                      = var.custom_domain
    ssl_certificate_name           = "cloudflare-origin-cert"
  }

  http_listener {
    name                           = "api-https-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    host_name                      = var.custom_domain_api
    ssl_certificate_name           = "cloudflare-origin-cert"
  }

  # Request routing rules - HTTP
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

  # Request routing rules - HTTPS
  request_routing_rule {
    name                       = "web-https-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "web-https-listener"
    backend_address_pool_name  = "web-backend-pool"
    backend_http_settings_name = "web-http-settings"
    priority                   = 300
  }

  request_routing_rule {
    name                       = "api-https-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "api-https-listener"
    backend_address_pool_name  = "api-backend-pool"
    backend_http_settings_name = "api-http-settings"
    priority                   = 400
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
  ttl     = 1  # Auto TTL when proxied
  proxied = true  # Enable Cloudflare proxy for free SSL
  comment = "Managed by Terraform (persistent) - web ${local.environment} environment"
}

resource "cloudflare_record" "api" {
  count   = var.custom_domain_api != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(var.custom_domain_api, ".jamly.eu")
  content = azurerm_public_ip.gateway.ip_address
  type    = "A"
  ttl     = 1  # Auto TTL when proxied
  proxied = true  # Enable Cloudflare proxy for free SSL
  comment = "Managed by Terraform (persistent) - API ${local.environment} environment"
}

