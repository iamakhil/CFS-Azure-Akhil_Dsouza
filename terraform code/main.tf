resource "azurerm_resource_group" "rgsea" {
  name     = var.rgname
  location = var.region
}

resource "azurerm_virtual_network" "vnetsea" {
  name                = "vnet-sea-001"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.rgsea.location
  resource_group_name = azurerm_resource_group.rgsea.name
}

resource "azurerm_subnet" "subnetwebservers" {
  name                 = "snet-webservers-001"
  resource_group_name  = azurerm_resource_group.rgsea.name
  virtual_network_name = azurerm_virtual_network.vnetsea.name
  address_prefixes     = ["10.1.1.0/24"]
}


resource "azurerm_subnet" "subnetjumpservers" {
  name                 = "snet-jumpservers-001"
  resource_group_name  = azurerm_resource_group.rgsea.name
  virtual_network_name = azurerm_virtual_network.vnetsea.name
  address_prefixes     = ["10.1.2.0/24"]
}

resource "azurerm_network_security_group" "nsgwebservers" {
  name                = "nsg-webservers1"
  location            = azurerm_resource_group.rgsea.location
  resource_group_name = azurerm_resource_group.rgsea.name

  security_rule {
    name                       = "allowrdphttp"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80","3389"]
    source_address_prefix      = "122.187.99.198"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsgassociate" {
  subnet_id                 = azurerm_subnet.subnetwebservers.id
  network_security_group_id = azurerm_network_security_group.nsgwebservers.id
}

resource "azurerm_availability_set" "avset" {
 name                         = "avail-webservers"
 location                     = azurerm_resource_group.rgsea.location
 resource_group_name          = azurerm_resource_group.rgsea.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
}

resource "azurerm_network_interface" "nicwebvm1" {
  name                = "nic-webvm-1"
  location            = azurerm_resource_group.rgsea.location
  resource_group_name = azurerm_resource_group.rgsea.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnetwebservers.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vmweb1" {
  name                = "vm-webserver1"
  resource_group_name = azurerm_resource_group.rgsea.name
  location            = azurerm_resource_group.rgsea.location
  availability_set_id = azurerm_availability_set.avset.id
  size                = "Standard_DS1_v2"
  admin_username      = "vmadmin"
  admin_password      = "admin@123"
  network_interface_ids = [
    azurerm_network_interface.nicwebvm1.id,
  ]

  os_disk {
    caching              = "None"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "nicwebvm2" {
  name                = "nic-webvm-2"
  location            = azurerm_resource_group.rgsea.location
  resource_group_name = azurerm_resource_group.rgsea.name

  ip_configuration {
    name                          = "internal1"
    subnet_id                     = azurerm_subnet.subnetwebservers.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vmweb2" {
  name                = "vm-webserver2"
  resource_group_name = azurerm_resource_group.rgsea.name
  location            = azurerm_resource_group.rgsea.location
  availability_set_id = azurerm_availability_set.avset.id
  size                = "Standard_DS1_v2"
  admin_username      = "vmadmin"
  admin_password      = "admin@123"
  network_interface_ids = [
    azurerm_network_interface.nicwebvm2.id,
  ]

  os_disk {
    caching              = "None"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "vmpublicip" {
  name                = "vmpublicip"
  location            = azurerm_resource_group.rgsea.location
  resource_group_name = azurerm_resource_group.rgsea.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_network_security_group" "nsgjumpservers" {
  name                = "nsg-jumpservers1"
  location            = azurerm_resource_group.rgsea.location
  resource_group_name = azurerm_resource_group.rgsea.name

  security_rule {
    name                       = "allowrdphttp"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80","3389"]
    source_address_prefix      = "122.187.99.198"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsgassociatejump" {
  subnet_id                 = azurerm_subnet.subnetjumpservers.id
  network_security_group_id = azurerm_network_security_group.nsgjumpservers.id
}

resource "azurerm_network_interface" "nicjumpvm1" {
  name                = "nic-jumpvm-1"
  location            = azurerm_resource_group.rgsea.location
  resource_group_name = azurerm_resource_group.rgsea.name

  ip_configuration {
    name                          = "jump"
    subnet_id                     = azurerm_subnet.subnetjumpservers.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vmpublicip.id
  }
}

resource "azurerm_windows_virtual_machine" "jumpweb1" {
  name                = "vm-jumpserver1"
  resource_group_name = azurerm_resource_group.rgsea.name
  location            = azurerm_resource_group.rgsea.location
  size                = "Standard_DS1_v2"
  admin_username      = "vmadmin"
  admin_password      = "admin@123"
  network_interface_ids = [
    azurerm_network_interface.nicjumpvm1.id,
  ]

  os_disk {
    caching              = "None"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}


resource "azurerm_public_ip" "lbpublicip" {
  name                = "lbpublicip"
  location            = azurerm_resource_group.rgsea.location
  resource_group_name = azurerm_resource_group.rgsea.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_lb" "lbwebservers" {
  name                = "lb-sea-webservers"
  location            = azurerm_resource_group.rgsea.location
  resource_group_name = azurerm_resource_group.rgsea.name
  sku                 = "Basic"

  frontend_ip_configuration {
    name                 = "lbpublicip"
    public_ip_address_id = azurerm_public_ip.lbpublicip.id
  }
}

resource "azurerm_lb_backend_address_pool" "lbbackendpool" {
  loadbalancer_id = azurerm_lb.lbwebservers.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "lbprobe" {
  resource_group_name = azurerm_resource_group.rgsea.name
  loadbalancer_id     = azurerm_lb.lbwebservers.id
  name                = "myprobe"
  port                = 80
  interval_in_seconds = 10
  number_of_probes    = 3
  protocol            = "Http"
  request_path        = "/"
}

resource "azurerm_lb_rule" "lbrule" {
  resource_group_name            = azurerm_resource_group.rgsea.name
  loadbalancer_id                = azurerm_lb.lbwebservers.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "lbpublicip"
  load_distribution              = "SourceIP"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lbbackendpool.id
  probe_id                       = azurerm_lb_probe.lbprobe.id
}

resource "azurerm_lb_nat_rule" "natrule" {
  resource_group_name            = azurerm_resource_group.rgsea.name
  loadbalancer_id                = azurerm_lb.lbwebservers.id
  name                           = "RDPAccess"
  protocol                       = "Tcp"
  frontend_port                  = 8050
  backend_port                   = 3389
  frontend_ip_configuration_name = "lbpublicip"
}





resource "azurerm_network_interface_backend_address_pool_association" "backendnic" {
  network_interface_id    = azurerm_network_interface.nicwebvm1.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbbackendpool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "backendnic1" {
  network_interface_id    = azurerm_network_interface.nicwebvm2.id
  ip_configuration_name   = "internal1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbbackendpool.id
}


resource "azurerm_network_interface_nat_rule_association" "natassociate" {
  network_interface_id  = azurerm_network_interface.nicwebvm1.id
  ip_configuration_name = "internal"
  nat_rule_id           = azurerm_lb_nat_rule.natrule.id
}

resource "azurerm_resource_group" "rgeus" {
  name     = var.rgname2
  location = var.region2
}

resource "azurerm_virtual_network" "vneteus" {
  name                = "vnet-eus-001"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.rgeus.location
  resource_group_name = azurerm_resource_group.rgeus.name
}

resource "azurerm_subnet" "subnetservers" {
  name                 = "snet-servers-001"
  resource_group_name  = azurerm_resource_group.rgeus.name
  virtual_network_name = azurerm_virtual_network.vneteus.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_network_security_group" "nsgservers11" {
  name                = "nsg-servers11"
  location            = azurerm_resource_group.rgeus.location
  resource_group_name = azurerm_resource_group.rgeus.name

  security_rule {
    name                       = "allowrdphttp"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80","3389"]
    source_address_prefix      = "122.187.99.198"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsgassociateserver11" {
  subnet_id                 = azurerm_subnet.subnetservers.id
  network_security_group_id = azurerm_network_security_group.nsgservers11.id
}

resource "azurerm_public_ip" "serverpublicip" {
  name                = "serverpublicip"
  location            = azurerm_resource_group.rgeus.location
  resource_group_name = azurerm_resource_group.rgeus.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "nicservervm" {
  name                = "nic-servervm"
  location            = azurerm_resource_group.rgeus.location
  resource_group_name = azurerm_resource_group.rgeus.name

  ip_configuration {
    name                          = "server11"
    subnet_id                     = azurerm_subnet.subnetservers.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.serverpublicip.id
  }
}

resource "azurerm_windows_virtual_machine" "server11" {
  name                = "vm-server11"
  resource_group_name = azurerm_resource_group.rgeus.name
  location            = azurerm_resource_group.rgeus.location
  size                = "Standard_DS1_v2"
  admin_username      = "vmadmin"
  admin_password      = "admin@123"
  network_interface_ids = [
    azurerm_network_interface.nicservervm.id,
  ]

  os_disk {
    caching              = "None"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}


resource "azurerm_virtual_network_peering" "eustosea" {
  name                      = "eustosea"
  resource_group_name       = azurerm_resource_group.rgeus.name
  virtual_network_name      = azurerm_virtual_network.vneteus.name
  remote_virtual_network_id = azurerm_virtual_network.vnetsea.id
}

resource "azurerm_virtual_network_peering" "seatoeus" {
  name                      = "seatoeus"
  resource_group_name       = azurerm_resource_group.rgsea.name
  virtual_network_name      = azurerm_virtual_network.vnetsea.name
  remote_virtual_network_id = azurerm_virtual_network.vneteus.id
}

resource "azurerm_storage_account" "stgacct1" {
  name                     = "strgnh101"
  resource_group_name      = azurerm_resource_group.rgeus.name
  location                 = azurerm_resource_group.rgeus.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"
}

resource "azurerm_storage_share" "stgshr" {
  name                 = "sales001"
  storage_account_name = azurerm_storage_account.stgacct1.name
  quota                = 1

}

resource "azurerm_storage_account" "stgacct2" {
  name                     = "strgnh102"
  resource_group_name      = azurerm_resource_group.rgsea.name
  location                 = azurerm_resource_group.rgsea.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

data "azurerm_storage_account_sas" "stgsas" {
  connection_string = azurerm_storage_account.stgacct1.primary_connection_string
  signed_version    = "2021-07-18"

  resource_types {
    service   = true
    container = false
    object    = false
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = true
  }

  start  = "2021-07-18T00:00:00Z"
  expiry = "2021-08-18T00:00:00Z"

  permissions {
    read    = true
    write   = true
    delete  = false
    list    = false
    add     = true
    create  = true
    update  = false
    process = false
  }
}

resource "azuread_user" "vmadmin" {
  user_principal_name = "vmadmin@dszakhiloutlook.onmicrosoft.com"
  display_name        = "akhil"
  mail_nickname       = "ak"
  password            = "admin@123"
}


resource "azuread_user" "backupadmin" {
  user_principal_name = "backupadmin@dszakhiloutlook.onmicrosoft.com"
  display_name        = "J. Doe"
  mail_nickname       = "jdoe"
  password            = "admin@123"
}

data "azurerm_subscription" "sub" {
}

resource "azurerm_role_assignment" "backupadmin" {
  scope                = "/subscriptions/4208f520-b385-4898-a89b-cf2de22f4a29/resourceGroups/rg-eus-nh"
  role_definition_name = "Backup Contributor"
  principal_id         = azuread_user.backupadmin.object_id
}

resource "azurerm_virtual_machine_extension" "vm_extension_install_iis_web1" {
  name                       = "vm_extension_install_iis"
  virtual_machine_id         = azurerm_windows_virtual_machine.vmweb1.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeManagementTools"
    }
SETTINGS
}

resource "azurerm_virtual_machine_extension" "vm_extension_install_iis_web2" {
  name                       = "vm_extension_install_iis"
  virtual_machine_id         = azurerm_windows_virtual_machine.vmweb2.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeManagementTools"
    }
SETTINGS
}

