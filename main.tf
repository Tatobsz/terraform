resource "azurerm_resource_group" "impacta-activity" {
  name     = "impacta-activity-resources"
  location = "West Europe"
}

resource "azurerm_virtual_network" "impacta-activity" {
  name                = "impacta-activity-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.impacta-activity.location
  resource_group_name = azurerm_resource_group.impacta-activity.name
}

resource "azurerm_subnet" "impacta-activity" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.impacta-activity.name
  virtual_network_name = azurerm_virtual_network.impacta-activity.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "publicip" {
  name                = "publicip"
  resource_group_name = azurerm_resource_group.impacta-activity.name
  location            = azurerm_resource_group.impacta-activity.location
  allocation_method   = "Static"

  tags = {
    turma      = "as04"
    disciplina = "infra cloud"
    professor  = "João"
  }
}

resource "azurerm_network_interface" "impacta-activity" {
  name                = "impacta-activity-nic"
  location            = azurerm_resource_group.impacta-activity.location
  resource_group_name = azurerm_resource_group.impacta-activity.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.impacta-activity.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_security_group" "infra-ng" {
  name                = "infra-ng"
  location            = azurerm_resource_group.impacta-activity.location
  resource_group_name = azurerm_resource_group.impacta-activity.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Web"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "ng-nic-assoc" {
  network_interface_id      = azurerm_network_interface.impacta-activity.id
  network_security_group_id = azurerm_network_security_group.infra-ng.id
}

resource "tls_private_key" "private-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}


resource "azurerm_linux_virtual_machine" "impacta-activity" {
  name                = "impacta-activity-machine"
  resource_group_name = azurerm_resource_group.impacta-activity.name
  location            = azurerm_resource_group.impacta-activity.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.impacta-activity.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.private-key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

resource "null_resource" "install-nginx" {
  triggers = {
    order = azurerm_linux_virtual_machine.impacta-activity.id
  }

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.publicip.ip_address
    user        = "adminuser"
    private_key = tls_private_key.private-key.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y nginx"
    ]
  }

  depends_on = [
    azurerm_linux_virtual_machine.impacta-activity
  ]
}

output "public_ip_nginx" {
  value = "http://${azurerm_public_ip.publicip.ip_address}"
}
