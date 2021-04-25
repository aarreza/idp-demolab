# The subnet for workstation
resource "azurerm_subnet" "workstations" {
  name                 = "workstations"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.11.0/24"]
}

# Create 1 network interface per workstation
resource "azurerm_network_interface" "workstations_nic" {
  count = var.num_workstations
  name                = "workstation-${count.index + 1}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  ip_configuration {
    name                          = "static"
    subnet_id                     = azurerm_subnet.workstations.id
    private_ip_address_allocation = "Static"
    # Private IP subnet
    private_ip_address            = cidrhost("10.0.11.0/24", 100 + count.index)
    public_ip_address_id          = azurerm_public_ip.workstation[count.index].id
  }
}

# Create 1 public IP per workstation
resource "azurerm_public_ip" "workstation" {
  count = var.num_workstations
  name                    = "workstation-${count.index + 1}-public-ip"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  allocation_method       = "Static"
}

# Network security group for workstation(s)
resource "azurerm_network_security_group" "workstations" {
  name                = "workstations-nsg"
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


# Associate our network security group with the NIC of our workstations
resource "azurerm_network_interface_security_group_association" "workstations" {
  count = var.num_workstations
  network_interface_id      = azurerm_network_interface.workstations_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.workstations.id
}
