# Note: you'll need to run 'terraform init' before terraform apply-ing this, because 'random_password' is a new provider
# Generates a random password for our domain controller
resource "random_password" "domain_controller_password" {
  length = 16
  special = false
}

# VM for our domain controller
resource "azurerm_virtual_machine" "domain_controller" {
  name                  = "domain-controller"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_D1_v2"
  # Base image
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  # Disk
  delete_os_disk_on_termination = true
  storage_os_disk {
    name              = "domain-controller-os-disk"
    create_option     = "FromImage"
  }
  os_profile {
    computer_name  = "DC-1"
    # Note: you can't use admin or Administrator in here, Azure won't allow you to do so :-)
    admin_username = "drew"
    admin_password = random_password.domain_controller_password.result
  }
  os_profile_windows_config {
    # Enable WinRM - we'll need to later
    winrm {
      protocol = "HTTP"
    }
  }
  # Explicit depend on domain controller nic, so when we terraform destroy, there will be no errors
  depends_on = [
   azurerm_network_interface_security_group_association.domain_controller
 ]

  tags = {
    # Needed for Ansible later
    kind = "domain_controller"
  }

  provisioner "local-exec" {
    working_dir = "${path.root}/../ansible"
    command = "ansible-playbook domain-controllers.yml --user drew -e ansible_password=${random_password.domain_controller_password.result} -e AZURE_RESOURCE_GROUPS=${azurerm_resource_group.main.name} -v"
  }
}
