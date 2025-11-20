# Public IP
resource "azurerm_public_ip" "database" {
  name                = "${local.name_prefix}-pip-db"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# Network Interface
resource "azurerm_network_interface" "database" {
  name                = "${local.name_prefix}-nic-db"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.database.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.database.id
  }
}

# Associate NSG with Network Interface
resource "azurerm_network_interface_security_group_association" "database" {
  network_interface_id      = azurerm_network_interface.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "database" {
  name                  = "${local.name_prefix}-vm-db"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.database.id]
  size                  = var.vm_size_database
  tags                  = local.common_tags

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    name                 = "${local.name_prefix}-osdisk-db"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.vm_os_disk_size_gb_database
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}