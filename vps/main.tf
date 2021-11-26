# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "${var.prefix}-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic1"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_network_security_rule" "jenkins" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "${var.prefix}-nsr-8080"
  priority                    = 100
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefixes     = ["my_ip etc"]
  destination_port_range      = "8080"
  destination_address_prefix  = azurerm_network_interface.main.private_ip_address
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "ssh" {
  access                     = "Allow"
  direction                  = "Inbound"
  name                       = "${var.prefix}-nsr-ssh"
  priority                   = 200
  protocol                   = "Tcp"
  source_port_range          = "*"
  source_address_prefixes    = ["my_ip etc"]
  destination_port_range     = "22"
  destination_address_prefix = azurerm_network_interface.main.private_ip_address
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_interface_security_group_association" "main" {
  # network_interface_id      = azurerm_network_interface.internal.id
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_linux_virtual_machine" "main" {
  name                            = "${var.prefix}-vm"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  disable_password_authentication = true
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  admin_ssh_key {
    username = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

# prepare hosts file
data "template_file" "ansible_hosts" {
  template = "${file("${path.module}/ansible/templates/ansible-hosts.tmpl")}"
  depends_on = [
    azurerm_linux_virtual_machine.main,
  ]
  vars = {
    public-ip = "${azurerm_public_ip.pip.ip_address}"
  }
}

resource "local_file" "ansible_hosts_rendered" {
  content  = "${data.template_file.ansible_hosts.rendered}"
  filename = "${local.workdir}/output/ansible-hosts"
}

# # get vps fingerprint to the container's known_hosts
# resource "null_resource" "get_vps_fingerprint" {
#   depends_on = [
#     azurerm_linux_virtual_machine.main,
#   ]
#   provisioner "local-exec" {
#     command = "ssh-keyscan -H ${azurerm_public_ip.pip.ip_address} >> ~/.ssh/known_hosts"
#   }
# }

# install and start jenkins via ansible
resource "null_resource" "go_jenkins" {
  depends_on = [
    azurerm_linux_virtual_machine.main,
    # null_resource.get_vps_fingerprint,
    local_file.ansible_hosts_rendered,
  ]
  provisioner "local-exec" {
    # command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --inventory=${local.workdir}/output/ansible-hosts ${local.workdir}/ansible/main.yaml -e 'ansible_python_interpreter=/usr/bin/python3'"
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --inventory=${local.workdir}/output/ansible-hosts ${local.workdir}/ansible/main.yaml"
    working_dir = "${local.workdir}"
  }
}

