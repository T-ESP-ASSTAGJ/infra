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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

data "azurerm_client_config" "current" {}

provider "azurerm" {
  features {}
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

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

# Subnet for VMs (used by the ephemeral layer)
resource "azurerm_subnet" "subnet" {
  name                 = "${local.name_prefix}-vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Dedicated subnet for Application Gateway (cannot be shared with other resources)
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "${local.name_prefix}-appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Delegated subnet for PostgreSQL Flexible Server — lives here so it survives ephemeral destroy
resource "azurerm_subnet" "subnet-database" {
  name                 = "${local.name_prefix}-db-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "postgres-database-virtual-network-dns"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# NAT Gateway — gives worker node (private IP only) outbound internet access
# required for ESO to reach public Azure endpoints (Key Vault, IMDS, etc.)
resource "azurerm_public_ip" "nat" {
  name                = "${local.name_prefix}-nat-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_nat_gateway" "main" {
  name                = "${local.name_prefix}-nat-gw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"
  tags                = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "vm" {
  subnet_id      = azurerm_subnet.subnet.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# NSG for VM subnet — allows SSH and intra-VNet HTTP/HTTPS from App Gateway
resource "azurerm_network_security_group" "nsg" {
  name                = "${local.name_prefix}-vm-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_source_address
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP-from-AppGw"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS-from-AppGw"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "vm_subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# NSG for Application Gateway subnet
# Azure requires ports 65200-65535 open from GatewayManager for health probes
resource "azurerm_network_security_group" "appgw_nsg" {
  name                = "${local.name_prefix}-appgw-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  security_rule {
    name                       = "AppGwManagement"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "appgw_subnet_nsg" {
  subnet_id                 = azurerm_subnet.appgw_subnet.id
  network_security_group_id = azurerm_network_security_group.appgw_nsg.id
}

# Static Public IP for Application Gateway
resource "azurerm_public_ip" "gateway" {
  name                = "${local.name_prefix}-appgw-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${local.name_prefix}-appgw"
  tags                = local.common_tags
}

# Managed Identity for Application Gateway to access Key Vault
resource "azurerm_user_assigned_identity" "appgw" {
  name                = "${local.name_prefix}-appgw-identity"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.common_tags
}

# Application Gateway
resource "azurerm_application_gateway" "appgw" {
  name                = "${local.name_prefix}-appgw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.common_tags

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.gateway.id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_port {
    name = "https"
    port = 443
  }

  backend_address_pool {
    name = "default-pool"
  }

  probe {
    name                = "k8s-nodeport-probe"
    host                = "127.0.0.1"
    interval            = 30
    protocol            = "Http"
    path                = "/"
    timeout             = 30
    unhealthy_threshold = 3

    match {
      status_code = ["200-404"]
    }
  }

  backend_http_settings {
    name                  = "default-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 30080
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = "k8s-nodeport-probe"
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "default-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "default-pool"
    backend_http_settings_name = "default-http-settings"
    priority                   = 100
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw.id]
  }
}

# Key Vault for SSL certificates
resource "azurerm_key_vault" "certs" {
  name                       = "${var.project_name}-keyvl"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  tags                       = local.common_tags

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.appgw.principal_id

    secret_permissions = [
      "Get",
      "List",
    ]

    certificate_permissions = [
      "Get",
      "List",
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
      "Recover",
    ]

    certificate_permissions = [
      "Get",
      "List",
      "Create",
      "Import",
      "Delete",
      "Purge",
      "Recover",
      "Update",
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.eso.principal_id

    secret_permissions = ["Get", "List"]
  }
}

resource "azurerm_user_assigned_identity" "eso" {
  name                = "${local.name_prefix}-eso-identity"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.common_tags
}


resource "azurerm_storage_account" "storage_account" {
  name                     = "${replace(var.project_name, "-", "")}sa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "storage_container" {
  name                  = "${var.project_name}-content"
  container_access_type = "blob"
  storage_account_name  = azurerm_storage_account.storage_account.name
}

resource "azurerm_storage_share" "file_share" {
  name               = "${var.project_name}-share"
  storage_account_name = azurerm_storage_account.storage_account.name
  quota              = 5
}

# Cloudflare DNS Records (pointing to the static Application Gateway IP)
resource "cloudflare_record" "web" {
  count   = var.custom_domain != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = local.environment == "production" ? "@" : local.environment
  content = azurerm_public_ip.gateway.ip_address
  type    = "A"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform (persistent) - web ${local.environment} environment"
}

resource "cloudflare_record" "api" {
  count   = var.custom_domain_api != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(var.custom_domain_api, ".jamly.eu")
  content = azurerm_public_ip.gateway.ip_address
  type    = "A"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform (persistent) - API ${local.environment} environment"
}

resource "cloudflare_record" "argocd" {
  count   = var.custom_domain_argocd != "" && var.cloudflare_zone_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(var.custom_domain_argocd, ".jamly.eu")
  content = azurerm_public_ip.gateway.ip_address
  type    = "A"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform (persistent) - ArgoCD ${local.environment} environment"
}

# Auto-generate ephemeral/persistent.auto.tfvars — loaded automatically by Terraform alongside terraform.tfvars
resource "local_file" "ephemeral_tfvars" {
  filename        = "${path.module}/../ephemeral/persistent.auto.tfvars"
  file_permission = "0644"
  content         = <<-EOT
    # Auto-generated by the persistent Terraform layer — do not edit manually.
    # Re-run `terraform apply` in terraform/V2/persistent to refresh these values.

    vm_subnet_id                   = "${azurerm_subnet.subnet.id}"
    persistent_resource_group_name = "${azurerm_resource_group.rg.name}"
    appgw_backend_pool_id          = "${tolist(azurerm_application_gateway.appgw.backend_address_pool)[0].id}"
    eso_identity_id                = "${azurerm_user_assigned_identity.eso.id}"
    eso_identity_client_id         = "${azurerm_user_assigned_identity.eso.client_id}"
    eso_keyvault_url               = "${azurerm_key_vault.certs.vault_uri}"
    db_subnet_id                   = "${azurerm_subnet.subnet-database.id}"
    private_dns_zone_postgres_id   = "${azurerm_private_dns_zone.postgres.id}"
  EOT
}
