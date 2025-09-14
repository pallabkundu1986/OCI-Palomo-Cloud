# Lookup Oracle Linux Image for ARM shape
data "oci_core_images" "arm_image" {
  compartment_id       = var.tenancy_ocid
  operating_system     = "Oracle Linux"
  operating_system_version = "9"
  shape                = "VM.Standard.E3.Flex"
  sort_by              = "TIMECREATED"
  sort_order           = "DESC"

}

# Lookup Oracle Linux Image for AMD shape
data "oci_core_images" "amd_image" {
  compartment_id       = var.tenancy_ocid
  operating_system     = "Oracle Linux"
  operating_system_version = "7.9"
  shape                = "VM.Standard.E2.1.Micro"
  sort_by              = "TIMECREATED"
  sort_order           = "DESC"

}


# Lookup Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.tenancy_ocid
}

# Create VCN
resource "oci_core_vcn" "palomo_vcn" {
  cidr_block     = "10.0.0.0/16"
  display_name   = "palomo-vcn"
  compartment_id = var.compartment_ocid
  dns_label      = "palomovcn"
}

# Create Security List for Public Network (Allow SSH, HTTP, HTTPS and all outbound)
resource "oci_core_security_list" "public_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.palomo_vcn.id
  display_name   = "public-security-list"

  ingress_security_rules {
    protocol = "6"  # TCP
    source   = "152.58.183.96/32"
    tcp_options {
      min = 22
      max = 22
    }
  }
  
  ingress_security_rules {
    protocol = "6"  # TCP
    source   = "152.58.183.96/32"
    tcp_options {
      min = 443
      max = 443
    }
  }
  ingress_security_rules {
    protocol = "6"  # TCP
    source   = "152.58.183.96/32"
    tcp_options {
      min = 80
      max = 80
    }
  }

 ingress_security_rules {
  protocol = "6" # TCP
  source   = "152.58.183.96/32"
  tcp_options {
    min = 8080
    max = 8080
  }
}


  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# Create Security List for Private Network (Allow All)
resource "oci_core_security_list" "private_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.palomo_vcn.id
  display_name   = "private-security-list"

  ingress_security_rules {
    protocol = "6"  # TCP
    source   = "10.0.0.0/16"
    tcp_options {
      min = 1
      max = 65535
    }
  }

  ingress_security_rules {
    protocol = "1"   # ICMP
    source   = "10.0.0.0/16"
  }

 
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}


# Create Public subnet 
resource "oci_core_subnet" "public_subnet" { 
	vcn_id = oci_core_vcn.palomo_vcn.id 
	cidr_block = "10.0.10.0/24" 
	display_name = "public-subnet-1" 
	compartment_id = var.compartment_ocid 
	prohibit_public_ip_on_vnic = false 
	dns_label = "publicsubnet1" 
	route_table_id = oci_core_route_table.public_rt.id 
	security_list_ids = [oci_core_security_list.public_sl.id]  
	
}

# Create Palomo subnet
resource "oci_core_subnet" "palomo_subnet" {
  vcn_id                     = oci_core_vcn.palomo_vcn.id
  cidr_block                 = "10.0.20.0/24"
  display_name               = "public-subnet"
  compartment_id             = var.compartment_ocid
  prohibit_public_ip_on_vnic = true
  dns_label                  = "palomosubnet" 
  route_table_id = oci_core_route_table.private_rt.id
  security_list_ids = [oci_core_security_list.private_sl.id]
  availability_domain = null
}

# Create Private Subnet and attach Security List
resource "oci_core_subnet" "private_subnet" {
  vcn_id                     = oci_core_vcn.palomo_vcn.id
  cidr_block                 = "10.0.30.0/24"
  display_name               = "private_subnet"
  compartment_id             = var.compartment_ocid
  prohibit_public_ip_on_vnic = true
  dns_label                  = "privatesubnet" 
  security_list_ids = [oci_core_security_list.private_sl.id]
  route_table_id = oci_core_route_table.private_rt.id
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.palomo_vcn.id
  display_name   = "Internet-Gateway"
}

resource "oci_core_nat_gateway" "nat_gw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.palomo_vcn.id
  display_name   = "NAT-Gateway"
}


resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.palomo_vcn.id
  display_name   = "public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_route_table" "private_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.palomo_vcn.id
  display_name   = "private-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat_gw.id
  }
}

# Load Balancer
resource "oci_load_balancer_load_balancer" "public_lb" {
  compartment_id = var.compartment_ocid
  display_name   = "Public-LB"
  shape          = "flexible"
  subnet_ids     = [oci_core_subnet.public_subnet.id]
  
  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 100
  }
}

# Backend Set
resource "oci_load_balancer_backend_set" "public_backendset" {
  load_balancer_id = oci_load_balancer_load_balancer.public_lb.id
  name             = "public-backendset"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol    = "HTTP"
    port        = 8080
    url_path    = "/palomo.html"
    retries     = 3
  
  }
}

# Backend Servers (VM01 and VM02 private IPs)

resource "oci_load_balancer_backend" "server01_backend" {
  load_balancer_id = oci_load_balancer_load_balancer.public_lb.id
  backendset_name = oci_load_balancer_backend_set.public_backendset.name
  ip_address       = "10.0.20.10"
  port             = 8080
}

resource "oci_load_balancer_backend" "server02_backend" {
  load_balancer_id = oci_load_balancer_load_balancer.public_lb.id
  backendset_name = oci_load_balancer_backend_set.public_backendset.name
  ip_address       = "10.0.20.11"
  port             = 8080
}

# Listener (HTTP)
resource "oci_load_balancer_listener" "http_listener" {
  load_balancer_id         = oci_load_balancer_load_balancer.public_lb.id
  name                     = "http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.public_backendset.name
  protocol                 = "HTTP"
  port                     = 8080
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*()-_=+"
}

# Create Linux VM 1 (Public Access)
resource "oci_core_instance" "linux_vm1" {
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.E3.Flex"
  display_name        = "Public-Server01"
  fault_domain        = "FAULT-DOMAIN-1"

  shape_config {
    ocpus         = 1   # Minimum 1 OCPU for A1.Flex
    memory_in_gbs = 6   # Minimum 6 GB RAM for A1.Flex
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.palomo_subnet.id
    assign_public_ip = false
    hostname_label   = "VM-Server01"
	private_ip       = "10.0.20.10"
  }
    # Reference the ARM image data source
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.arm_image.images[0].id
	  }
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
	
		user_data = base64encode(<<-EOT
		#!/bin/bash
		set -euxo pipefail

		DB_PASS="${random_password.db_password.result}"
		DB_NAME="shopdb"
		DB_USER="shopuser"

		# Update system
		yum clean all
		yum makecache
		yum -y update

		# Install required packages
		for i in {1..5}; do
		  yum install -y httpd php php-mysqlnd php-fpm php-xml php-gd php-cli mariadb-server wget unzip policycoreutils-python-utils && break || sleep 10
		done

		# Configure Apache to listen on 8080
		sed -i 's/^Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf

		# Configure SELinux for port 8080
		if command -v semanage &>/dev/null; then
		  if ! semanage port -l | grep -qw "8080"; then
			semanage port -a -t http_port_t -p tcp 8080 || true
		  fi
		fi

		# Enable and start firewalld
		systemctl enable firewalld
		systemctl start firewalld
		firewall-cmd --permanent --add-port=8080/tcp
		firewall-cmd --reload

		# Enable and start Apache
		systemctl enable httpd
		systemctl restart httpd

		# Enable and start MariaDB
		systemctl enable mariadb
		systemctl start mariadb

		# Create DB and user
		mysql -e "CREATE DATABASE IF NOT EXISTS $${DB_NAME};"
		mysql -e "CREATE USER IF NOT EXISTS '$${DB_USER}'@'%' IDENTIFIED BY '$${DB_PASS}';"
		mysql -e "GRANT ALL PRIVILEGES ON $${DB_NAME}.* TO '$${DB_USER}'@'%'; FLUSH PRIVILEGES;"

		# Create health check page
		echo "OK" > /var/www/html/palomo.html
		chown apache:apache /var/www/html/palomo.html
		chmod 644 /var/www/html/palomo.html

		# Install WordPress
		cd /var/www/html
		wget https://wordpress.org/latest.tar.gz
		tar -xvzf latest.tar.gz
		mv wordpress/* . || true
		rm -rf wordpress latest.tar.gz
		chown -R apache:apache /var/www/html
		chmod -R 755 /var/www/html

		# Configure wp-config.php
		cp wp-config-sample.php wp-config.php
		sed -i "s/database_name_here/$${DB_NAME}/" wp-config.php
		sed -i "s/username_here/$${DB_USER}/" wp-config.php
		sed -i "s/password_here/$${DB_PASS}/" wp-config.php

		# Add WordPress salts
		curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> wp-config.php

		# Restart Apache
		systemctl restart httpd
		EOT
		)
  
  }  
}

# --- VM1 Private IP ---
data "oci_core_vnic_attachments" "vm1_vnics" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.linux_vm1.id
}

data "oci_core_vnic" "vm1_vnic" {
  vnic_id = data.oci_core_vnic_attachments.vm1_vnics.vnic_attachments[0].vnic_id
}

# Create Linux VM 2 (Public Access)
resource "oci_core_instance" "linux_vm2" {
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.E3.Flex"
  display_name        = "Public-Server02"
  fault_domain        = "FAULT-DOMAIN-2"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.palomo_subnet.id
    assign_public_ip = false
    hostname_label   = "VM-Server02"
	private_ip       = "10.0.20.11"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.arm_image.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
	
		user_data = base64encode(<<-EOT
		#!/bin/bash
		set -euxo pipefail

		DB_PASS="${random_password.db_password.result}"
		DB_NAME="shopdb"
		DB_USER="shopuser"

		# Update system
		yum clean all
		yum makecache
		yum -y update

		# Install required packages
		for i in {1..5}; do
		  yum install -y httpd php php-mysqlnd php-fpm php-xml php-gd php-cli mariadb-server wget unzip policycoreutils-python-utils && break || sleep 10
		done

		# Configure Apache to listen on 8080
		sed -i 's/^Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf

		# Configure SELinux for port 8080
		if command -v semanage &>/dev/null; then
		  if ! semanage port -l | grep -qw "8080"; then
			semanage port -a -t http_port_t -p tcp 8080 || true
		  fi
		fi

		# Enable and start firewalld
		systemctl enable firewalld
		systemctl start firewalld
		firewall-cmd --permanent --add-port=8080/tcp
		firewall-cmd --reload

		# Enable and start Apache
		systemctl enable httpd
		systemctl restart httpd

		# Enable and start MariaDB
		systemctl enable mariadb
		systemctl start mariadb

		# Create DB and user
		mysql -e "CREATE DATABASE IF NOT EXISTS $${DB_NAME};"
		mysql -e "CREATE USER IF NOT EXISTS '$${DB_USER}'@'%' IDENTIFIED BY '$${DB_PASS}';"
		mysql -e "GRANT ALL PRIVILEGES ON $${DB_NAME}.* TO '$${DB_USER}'@'%'; FLUSH PRIVILEGES;"

		# Create health check page
		echo "OK" > /var/www/html/palomo.html
		chown apache:apache /var/www/html/palomo.html
		chmod 644 /var/www/html/palomo.html

		# Install WordPress
		cd /var/www/html
		wget https://wordpress.org/latest.tar.gz
		tar -xvzf latest.tar.gz
		mv wordpress/* . || true
		rm -rf wordpress latest.tar.gz
		chown -R apache:apache /var/www/html
		chmod -R 755 /var/www/html

		# Configure wp-config.php
		cp wp-config-sample.php wp-config.php
		sed -i "s/database_name_here/$${DB_NAME}/" wp-config.php
		sed -i "s/username_here/$${DB_USER}/" wp-config.php
		sed -i "s/password_here/$${DB_PASS}/" wp-config.php

		# Add WordPress salts
		curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> wp-config.php

		# Restart Apache
		systemctl restart httpd
		EOT
		)
	
  }
}
# --- VM2 Private IP ---
data "oci_core_vnic_attachments" "vm2_vnics" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.linux_vm2.id
}

data "oci_core_vnic" "vm2_vnic" {
  vnic_id = data.oci_core_vnic_attachments.vm2_vnics.vnic_attachments[0].vnic_id
}


 # Create Linux VM 3 (Private Access) 
  resource "oci_core_instance" "linux_vm3" {
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.E2.1.Micro"
  display_name        = "Private-VM01"

  create_vnic_details {
    subnet_id        = oci_core_subnet.private_subnet.id
    assign_public_ip = false
    hostname_label   = "Lab-VM01"
  }

  # Reference the AMD image data source
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.amd_image.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

 # Create Linux VM 4 (Public Access) 
  resource "oci_core_instance" "linux_vm4" {
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.E2.1.Micro"
  display_name        = "Public-VM04"

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
    hostname_label   = "Public-VM04"
  }

  # Reference the AMD image data source
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.amd_image.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}
