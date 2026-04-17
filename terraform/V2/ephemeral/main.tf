terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

locals {
  environment = terraform.workspace
  name_prefix = "${var.project_name}-${local.environment}"
  common_tags = merge(
    var.tags,
    {
      Environment = local.environment
      Project     = var.project_name
      Layer       = "ephemeral"
    }
  )
}

# ── Resource Group ─────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "ephemeral" {
  name     = "${local.name_prefix}-ephemeral-rg"
  location = var.location
  tags     = local.common_tags
}

# ── Extra NSG rules on the persistent VM subnet NSG ───────────────────────────
# The persistent layer already handles SSH/HTTP/HTTPS.
# Ephemeral adds Kubernetes-specific rules; they are removed on destroy.

data "azurerm_network_security_group" "vm_nsg" {
  # The persistent layer names the NSG "<project>-<env>-vm-nsg", matching its own name_prefix.
  # Derive that prefix by stripping the "-rg" suffix from the persistent resource group name.
  name                = "${trimsuffix(var.persistent_resource_group_name, "-rg")}-vm-nsg"
  resource_group_name = var.persistent_resource_group_name
}

data "azurerm_virtual_network" "persistent" {
  name                = "${trimsuffix(var.persistent_resource_group_name, "-rg")}-vnet"
  resource_group_name = var.persistent_resource_group_name
}

resource "azurerm_network_security_rule" "vxlan" {
  name                        = "VXLAN-Cilium"
  priority                    = 1100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "8472"
  source_address_prefix       = "10.0.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = var.persistent_resource_group_name
  network_security_group_name = data.azurerm_network_security_group.vm_nsg.name
}

resource "azurerm_network_security_rule" "kubelet" {
  name                        = "Kubelet-API"
  priority                    = 1101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "10250"
  source_address_prefix       = "10.0.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = var.persistent_resource_group_name
  network_security_group_name = data.azurerm_network_security_group.vm_nsg.name
}

resource "azurerm_network_security_rule" "k8s_api" {
  name                        = "K8s-API-Server"
  priority                    = 1102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6443"
  source_address_prefix       = "10.0.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = var.persistent_resource_group_name
  network_security_group_name = data.azurerm_network_security_group.vm_nsg.name
}

resource "azurerm_network_security_rule" "etcd" {
  name                        = "etcd"
  priority                    = 1103
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "2379-2380"
  source_address_prefix       = "10.0.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = var.persistent_resource_group_name
  network_security_group_name = data.azurerm_network_security_group.vm_nsg.name
}

resource "azurerm_network_security_rule" "nodeport" {
  name                        = "NodePort-from-AppGw"
  priority                    = 1104
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "30000-32767"
  source_address_prefix       = "10.0.2.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = var.persistent_resource_group_name
  network_security_group_name = data.azurerm_network_security_group.vm_nsg.name
}

# ── Control Plane VM ──────────────────────────────────────────────────────────
# Public IP required: Ansible SSH entry point + kubeadm advertise address

resource "azurerm_public_ip" "control_plane" {
  name                = "${local.name_prefix}-cp-pip"
  location            = azurerm_resource_group.ephemeral.location
  resource_group_name = azurerm_resource_group.ephemeral.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "control_plane" {
  name                = "${local.name_prefix}-cp-nic"
  location            = azurerm_resource_group.ephemeral.location
  resource_group_name = azurerm_resource_group.ephemeral.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.vm_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.control_plane.id
  }
}

resource "azurerm_linux_virtual_machine" "control_plane" {
  name                            = "jamlycp"
  location                        = azurerm_resource_group.ephemeral.location
  resource_group_name             = azurerm_resource_group.ephemeral.name
  size                            = var.vm_size_control_plane
  admin_username                  = var.admin_username
  disable_password_authentication = true
  tags                            = local.common_tags

  network_interface_ids = [azurerm_network_interface.control_plane.id]

  dynamic "admin_ssh_key" {
    for_each = var.ssh_public_key
    content {
      username   = var.admin_username
      public_key = admin_ssh_key.value
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 50
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# ── Worker VM ─────────────────────────────────────────────────────────────────
# Private IP only — Ansible reaches it via ProxyJump through the control plane.
# Its NIC is registered in the AppGW backend pool (receives NodePort traffic).

resource "azurerm_network_interface" "worker" {
  name                = "${local.name_prefix}-worker-nic"
  location            = azurerm_resource_group.ephemeral.location
  resource_group_name = azurerm_resource_group.ephemeral.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.vm_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "worker" {
  network_interface_id    = azurerm_network_interface.worker.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = var.appgw_backend_pool_id
}

resource "azurerm_linux_virtual_machine" "worker" {
  name                            = "jamlyw1"
  location                        = azurerm_resource_group.ephemeral.location
  resource_group_name             = azurerm_resource_group.ephemeral.name
  size                            = var.vm_size_worker
  admin_username                  = var.admin_username
  disable_password_authentication = true
  tags                            = local.common_tags

  network_interface_ids = [azurerm_network_interface.worker.id]

  dynamic "admin_ssh_key" {
    for_each = var.ssh_public_key
    content {
      username   = var.admin_username
      public_key = admin_ssh_key.value
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 50
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.eso_identity_id]
  }
}

resource "azurerm_postgresql_flexible_server" "server-database" {
  name                = "${var.project_name}-postgresql-server-1"
  resource_group_name = azurerm_resource_group.ephemeral.name
  location            = azurerm_resource_group.ephemeral.location
  zone                = "3"
  version             = "13"

  administrator_login    = var.db_admin_login
  administrator_password = var.db_admin_password

  backup_retention_days = 7

  storage_mb  = 32768
  sku_name    = "B_Standard_B1ms"

  public_network_access_enabled = false
  delegated_subnet_id           = var.db_subnet_id
  private_dns_zone_id           = var.private_dns_zone_postgres_id
}

resource "azurerm_postgresql_flexible_server_database" "database-jamly" {
  name                = "${var.project_name}-database-1"
  server_id           = azurerm_postgresql_flexible_server.server-database.id
  collation           = "en_US.utf8"
  charset             = "UTF8"

  lifecycle {
    prevent_destroy = false
  }
}

# ── Ansible Inventory ─────────────────────────────────────────────────────────

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../templates/inventory.tpl", {
    cp_public_ip           = azurerm_public_ip.control_plane.ip_address
    cp_private_ip          = azurerm_network_interface.control_plane.private_ip_address
    w1_private_ip          = azurerm_network_interface.worker.private_ip_address
    admin_user             = var.admin_username
    eso_identity_client_id = var.eso_identity_client_id
    eso_keyvault_url       = var.eso_keyvault_url
  })
  filename        = "${path.module}/../../../ansible/inventory/hosts.ini"
  file_permission = "0600"
}
