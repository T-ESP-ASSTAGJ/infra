# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "V2-${var.project_name}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project_name}vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.project_name}subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "subnet-database" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

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
  name                  = "postgres-databse-virtual-network-dns"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_network_security_group" "nsg" {
  name = "${var.project_name}nsg"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name = "SSH"
    priority = 1001
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id = azurerm_network_interface.net.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "public_ip" {
  name                = "${var.project_name}publicip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "net" {
  name                = "${var.project_name}nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "${var.project_name}cp"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_F4s_v2"
  admin_username        = "tfou3lik"
  network_interface_ids = [azurerm_network_interface.net.id]

  admin_ssh_key {
    username   = "tfou3lik"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}


resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    vm_ip         = azurerm_public_ip.public_ip.ip_address
    vm_private_ip = azurerm_network_interface.net.private_ip_address
    vm_name       = azurerm_linux_virtual_machine.vm.name
    admin_user    = "tfou3lik"
  })
  filename = "${path.module}/../../ansible/inventory/hosts.ini"

  depends_on = [
    azurerm_linux_virtual_machine.vm,
    azurerm_public_ip.public_ip
  ]
}

resource "azurerm_postgresql_flexible_server" "server-database" {
  name                = "${var.project_name}-postgresql-server-1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  version                = "13"

  administrator_login    = var.db_admin_login
  administrator_password = var.db_admin_password

  backup_retention_days = 7

  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id
  delegated_subnet_id = azurerm_subnet.subnet-database.id
}

resource "azurerm_postgresql_flexible_server_database" "database-jamly" {
  name                = "${var.project_name}-database-1"
  server_id           = azurerm_postgresql_flexible_server.server-database.id
  collation           = "en_US.utf8"
  charset             = "UTF8"

  lifecycle {
    prevent_destroy = true
  }
}