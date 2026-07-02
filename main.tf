resource "azurerm_resource_group" "rg" {
  name     = "rg-lab-hardening-${var.yourname}"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-lab-hardening-${var.yourname}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-lab-hardening-${var.yourname}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-lab-hardening-${var.yourname}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
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
    name                       = "Allow-RDP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "linux" {
  name                = "nic-linux-${var.yourname}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.linux.id
  }
}

resource "azurerm_public_ip" "linux" {
  name                = "pip-linux-${var.yourname}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_linux_virtual_machine" "linux" {
  name                            = "vm-linux-${var.yourname}"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.linux.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
    
        #!/bin/bash
        apt-get update -y
        apt-get upgrade -y
        
        echo "install cramfd /bin/true" >> /etc/modprobe.d/disable-fs.conf
        echo "install freevxfs /bin/true" >> /etc/modprobe.d/disable-fs.conf

        systemctl disable avahi-daemon 2>/dev/null || true
        systemctl disable cups 2>/dev/null || true

        apt-get update -y && apt-get install  -y auditd
        systemctl enable auditd && systemctl start auditd

        sed -i "s/^#PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config
        sed -i "s/^#Protocol.*/Protocol 2/" /etc/ssh/sshd_config
        echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config
        echo "ClientAliveCountMax 0" >> /etc/ssh/sshd_config
        systemctl restart sshd

        apt-get install -y libpam-pwquality
        echo "minlen=14 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1" \
            >> /etc/security/pwquality.conf
        
        echo "auth required pam_faillock.so preauth silent audit deny=5 unlock_time=900" \
            >> /etc/pam.d/common-auth
        
        ufw --force enable
        ufw default deny incoming
        ufw allow 22/tcp
        echo "hardnening completed" > /var/log/hardening.log
    EOF
  )
}

resource "azurerm_network" "windows" {
  name                = "nic-windows-${var.yourname}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.windows.id
  }
}

resource "azurerm_public_ip" "windows" {
  name                = "pip-windows-${var.yourname}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_windows_virtual_machine" "windows" {
  name                  = "vm-windows-${var.yourname}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = "Standard_B1s"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network.windows.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

