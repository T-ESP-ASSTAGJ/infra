# Public IP
resource "azurerm_public_ip" "api" {
  name                = "${local.name_prefix}-pip-api"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# Network Interface
resource "azurerm_network_interface" "api" {
  name                = "${local.name_prefix}-nic-api"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.api.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.api.id
  }
}

# Associate NSG with Network Interface
resource "azurerm_network_interface_security_group_association" "api" {
  network_interface_id      = azurerm_network_interface.api.id
  network_security_group_id = azurerm_network_security_group.api.id
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "api" {
  name                  = "${local.name_prefix}-vm-api"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.api.id]
  size                  = var.vm_size
  tags                  = local.common_tags

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    name                 = "${local.name_prefix}-osdisk-api"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.vm_os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}