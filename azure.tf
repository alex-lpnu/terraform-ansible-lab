# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.86.0"
    }
  }
}
provider "azurerm" {
  features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "jupytergroup" {
  name     = "jupyterNotebookGroup"
  location = "eastus"

  tags = {
    environment = "Terraform Demo"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "jupyternetwork" {
  name                = "jupyterVnet"
  address_space       = ["10.0.0.0/16"]
  location            = "eastus"
  resource_group_name = azurerm_resource_group.jupytergroup.name

  tags = {
    environment = "Terraform Demo"
  }
}

# Create subnet
resource "azurerm_subnet" "jupytersubnet" {
  name                 = "jupyterSubNet"
  resource_group_name  = azurerm_resource_group.jupytergroup.name
  virtual_network_name = azurerm_virtual_network.jupyternetwork.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "jupyterPubIp" {
  name                = "jupyterPubIp"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.jupytergroup.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "Terraform Demo"
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "jupyternsg" {
  name                = "jupyternsg"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.jupytergroup.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Terraform Demo"
  }
}

# Create network interface
resource "azurerm_network_interface" "jupyternic" {
  name                = "jupyterNIC"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.jupytergroup.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = azurerm_subnet.jupytersubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jupyterPubIp.id
  }

  tags = {
    environment = "Terraform Demo"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.jupyternic.id
  network_security_group_id = azurerm_network_security_group.jupyternsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.jupytergroup.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "jupyterstorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = azurerm_resource_group.jupytergroup.name
  location                 = "eastus"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "Terraform Demo"
  }
}

# Create (and display) an SSH key
resource "tls_private_key" "jupyterssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
output "tls_private_key" {
  value     = tls_private_key.jupyterssh.private_key_pem
  sensitive = true
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "jupytervm" {
  name                  = "jupyter"
  location              = "eastus"
  resource_group_name   = azurerm_resource_group.jupytergroup.name
  network_interface_ids = [azurerm_network_interface.jupyternic.id]
  size                  = "Standard_B1ls"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "jupyter"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.jupyterssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.jupyterstorageaccount.primary_blob_endpoint
  }

  tags = {
    environment = "Terraform Demo"
  }
}
