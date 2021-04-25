# Generate a random password and reuse it for each local admin account on workstations
resource "random_password" "workstations_local_admin_password" {
  length  = 16
  special = false
}

# Windows 10 workstations
resource "azurerm_virtual_machine" "workstation" {
  count = var.num_workstations

  name                  = "workstation-${count.index + 1}"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.workstations_nic[count.index].id]
  vm_size               = "Standard_D1_v2"

  storage_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    #sku       = "19h1-pron"
    sku       = "20h2-pron"
    version   = "latest"
  }

  delete_os_disk_on_termination = true
  storage_os_disk {
    name              = "workstation-${count.index + 1}-os-disk"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = "WORKSTATION-${count.index + 1}"
    admin_username = "localadmin"
    admin_password = random_password.workstations_local_admin_password.result
  }
  os_profile_windows_config {
      winrm {
        protocol = "HTTP"
      }
  }

  # Explicit depend on workstations nic, so when we terraform destroy, there will be no errors
  depends_on = [
    azurerm_network_interface_security_group_association.workstations
  ]

  tags = {
    kind = "workstation"
  }
}

resource "null_resource" "provision_workstation_once_dc_has_been_created" {
  provisioner "local-exec" {
    working_dir = "${path.root}/../ansible"
    command = "ansible-playbook workstations.yml --user localadmin -e domain_admin_password=${random_password.domain_controller_password.result} -e ansible_password=${random_password.workstations_local_admin_password.result} -e AZURE_RESOURCE_GROUPS=${azurerm_resource_group.main.name} -v"
  }

  depends_on = [
    azurerm_virtual_machine.domain_controller,
    azurerm_virtual_machine.workstation
  ]
}
