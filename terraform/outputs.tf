# Displays domain controller public ip
output "domain_controller_public_ip" {
  value = azurerm_public_ip.main.ip_address
}

# # Display the dc local admin username
# output "local_admin_dc_username" {
#   value = nonsensitive(azurerm_virtual_machine.domain_controller.os_profile[*].admin_username)
# }

# Displays the domain controller password
output "domain_controller_password" {
  value =  nonsensitive(random_password.domain_controller_password.result)
}

# Displays workstation public ip(s)
output "workstations_public_ips" {
  value = azurerm_public_ip.workstation.*.ip_address
}

# Displays workstations password(s)
output "workstations_local_admin_password" {
  value = nonsensitive(random_password.workstations_local_admin_password.result)
}

# # Displays private ip address(es)
# output "workstation_private_ip" {
#   value =  azurerm_network_interface.workstations_nic.*.private_ip_address
# }
