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
    source   = "152.58.183.242/32"
    tcp_options {
      min = 22
      max = 22
    }
  }
  
  ingress_security_rules {
    protocol = "6"  # TCP
    source   = "152.58.183.242/32"
    tcp_options {
      min = 443
      max = 443
    }
  }
  ingress_security_rules {
    protocol = "6"  # TCP
    source   = "152.58.183.242/32"
    tcp_options {
      min = 80
      max = 80
    }
  }

 ingress_security_rules {
  protocol = "6" # TCP
  source   = "152.58.183.242/32"
  tcp_options {
    min = 8080
    max = 8080
  }
}

 ingress_security_rules {
  protocol = "6" # TCP
  source   = "10.0.0.0/16"
  tcp_options {
    min = 8080
    max = 8080
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

# Create Security List for Private Network (Allow All)
resource "oci_core_security_list" "private_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.palomo_vcn.id
  display_name   = "private-security-list"

  ingress_security_rules {
    protocol = "6"  # TCP
    source   = "10.0.1.0/24"
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

# Create Public Subnet and attach Security List
resource "oci_core_subnet" "public_subnet" {
  vcn_id                     = oci_core_vcn.palomo_vcn.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "public-subnet"
  compartment_id             = var.compartment_ocid
  prohibit_public_ip_on_vnic = false
  dns_label                  = "publicsubnet" 
  route_table_id = oci_core_route_table.public_rt.id

  # Attach security list
  security_list_ids = [
    oci_core_security_list.public_sl.id
  ]
}

# Create Private Subnet and attach Security List
resource "oci_core_subnet" "private_subnet" {
  vcn_id                     = oci_core_vcn.palomo_vcn.id
  cidr_block                 = "10.0.2.0/24"
  display_name               = "private_subnet"
  compartment_id             = var.compartment_ocid
  prohibit_public_ip_on_vnic = true
  dns_label                  = "privatesubnet" 

  # Attach security list
  security_list_ids = [
    oci_core_security_list.private_sl.id
  ]
  # Attach NAT route table
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


# Create Linux VM 1 (Public Access)
resource "oci_core_instance" "linux_vm1" {
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.E3.Flex"
  display_name        = "Public-Server01"

  shape_config {
    ocpus         = 1   # Minimum 1 OCPU for A1.Flex
    memory_in_gbs = 6   # Minimum 6 GB RAM for A1.Flex
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
    hostname_label   = "VM-Server01"
  }
    # Reference the ARM image data source
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.arm_image.images[0].id
	  }
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }  
}
# Create Linux VM 2 (Public Access)
resource "oci_core_instance" "linux_vm1_clone" {
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.E3.Flex"
  display_name        = "Public-Server02"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
    hostname_label   = "VM-Server02"
  }

  source_details {
    source_type = "image"
    source_id   = "ocid1.image.oc1.ap-hyderabad-1.aaaaaaaazf34fypegtnzvocmvjfs6hjwzezehinollgci24np3cqfp225ifq"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}


 # Create Linux VM 3 (Private Access) 
  resource "oci_core_instance" "linux_vm2" {
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
