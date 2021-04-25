# Resource group in East US
resource "azurerm_resource_group" "main" {
    name = "aa-identity-lab"
    location = "eastus"
}

# Virtual network of 10.0.0.0/16
resource "azurerm_virtual_network" "main" {
  name                = "virtual-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# The subnet for servers
resource "azurerm_subnet" "servers" {
  name                 = "servers"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.10.0/24"]
}

# The domain controller network interface
resource "azurerm_network_interface" "main" {
  name                = "domain-controller-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

# The domain controller private subnet
  ip_configuration {
    name                          = "static"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Static"
    private_ip_address = cidrhost("10.0.10.0/24", 10)
    public_ip_address_id = azurerm_public_ip.main.id
  }
}

# The domain controller public IP
resource "azurerm_public_ip" "main" {
  name                    = "dc-public-ip"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30
}

# Note: you'll need to run 'terraform init' before terraform apply-ing this, because 'http' is a new provider

# Dynamically retrieve our public outgoing IP
data "http" "outgoing_ip" {
  url = "http://ipv4.icanhazip.com"
}
locals {
  outgoing_ip = chomp(data.http.outgoing_ip.body)
}

# Network security group for domain controller
resource "azurerm_network_security_group" "domain_controller" {
  name                = "domain-controller-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # RDP
  security_rule {
    name                       = "Allow-RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "${local.outgoing_ip}/32"
    destination_address_prefix = "*"
  }

  # WinRM
  security_rule {
    name                       = "Allow-WinRM"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "${local.outgoing_ip}/32"
    destination_address_prefix = "*"
  }
}

# Associate our network security group with the NIC of our domain controller
resource "azurerm_network_interface_security_group_association" "domain_controller" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.domain_controller.id
}
