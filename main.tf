terraform {
    required_providers {
        azurerm = {
            version = ">=2.74.0"
            source = "hashicorp/azurerm"
        }
    }
}

provider "azurerm" {
  features {
  }
}

data "azurerm_resource_group" "rhel8-test" {
  name = "rhel8-test_group"
}

data "azurerm_managed_disk" "huge-disk" {
  name = "huge-disk"
  resource_group_name = data.azurerm_resource_group.rhel8-test.name
}

data "azurerm_virtual_network" "rhel8-vnet" {
  name = "rhel8-test_group-vnet"
  resource_group_name = data.azurerm_resource_group.rhel8-test.name
}

data "azurerm_subnet" "rhel8-subnet" {
  name = "default"
  virtual_network_name = data.azurerm_virtual_network.rhel8-vnet.name
  resource_group_name = data.azurerm_resource_group.rhel8-test.name
}

resource "azurerm_managed_disk" "copy-disk" {
  name = "copy-disk"
  create_option = "Copy"
  location = data.azurerm_resource_group.rhel8-test.location
  resource_group_name = data.azurerm_resource_group.rhel8-test.name
  source_resource_id = data.azurerm_managed_disk.huge-disk.id
  storage_account_type = data.azurerm_managed_disk.huge-disk.storage_account_type
  disk_size_gb = "4096"
}
resource "azurerm_network_interface" "new-vm-nic" {
  name = "new-vm-nic"
  location = data.azurerm_resource_group.rhel8-test.location
  resource_group_name = data.azurerm_resource_group.rhel8-test.name
  ip_configuration {
    name = "new-vm-nic-config"
    subnet_id = data.azurerm_subnet.rhel8-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
} 

resource "azurerm_virtual_machine" "new-vm-with-attached-disk" {
    name = "new-vm-with-disk"
    resource_group_name = data.azurerm_resource_group.rhel8-test.name
    vm_size = "Standard_D4s_v3"
    location = data.azurerm_resource_group.rhel8-test.location
    network_interface_ids = [ azurerm_network_interface.new-vm-nic.id ]
    
    storage_image_reference {
      publisher = "RedHat"
      offer = "RHEL"
      version = "latest"
      sku = "8.2"
    }
    
    storage_os_disk {
      name = "newdisk1"
      caching = "ReadWrite"
      create_option = "FromImage"
      managed_disk_type = "Premium_LRS"
    }
    
    os_profile {
        computer_name = "new-vm-disk"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path = "/home/azureuser/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDNsdeLCrNle9r6LgTRFtWCUgpRJqFHz+vf8wbb044vd4+dtL9pOsNbIbMvqMc2sQBWdE2jFfEDfmqgnjqhnDhf6cQJgm1TZXm6pmQg99OuiyNlalVyboeAP9d/Vc08kHNskRIwx8gW075EgBhknSqihVqywv8n/L8x0AENpJprEMA/mmhQ/SMv/npk4lnjj3LseP0i4wZX5ZH+sxw+3+gkeMOwvAHXyeC/BYt2tgSh7Cy1hqAoWFltiSTpF0+UNJ2vhz8o/BAIxXc5TWioXoP16xwcSun8jgMpny+CVn+yCsJUwx81Pro3sxFQa6qbLW2BjS5N5p5E4LIIhOjwnHKb jstanley@i.am.jds2001.org"
        }
    }
}

resource "azurerm_virtual_machine_data_disk_attachment" "copy-disk-attach" {
  managed_disk_id = azurerm_managed_disk.copy-disk.id
  virtual_machine_id = azurerm_virtual_machine.new-vm-with-attached-disk.id
  lun = "1"
  caching = "None"
}