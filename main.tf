# Lookup Oracle Linux Image (in root compartment)
data "oci_core_images" "oracle_linux" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = "VM.Standard.E2.1.Micro"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Lookup Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.tenancy_ocid
}

# Create VCN
resource "oci_core_vcn" "fin_vcn" {
  cidr_block     = "10.0.0.0/16"
  display_name   = "fin-vcn"
  compartment_id = var.compartment_ocid
  dns_label      = "finvcn"
}

# Create Security List (Allow SSH and all outbound)
resource "oci_core_security_list" "public_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.fin_vcn.id
  display_name   = "public-security-list"

  ingress_security_rules {
    protocol = "6"  # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# Create Public Subnet and attach Security List
resource "oci_core_subnet" "public_subnet" {
  vcn_id                     = oci_core_vcn.fin_vcn.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "public-subnet"
  compartment_id             = var.compartment_ocid
  prohibit_public_ip_on_vnic = false
  dns_label                  = "publicsubnet" 

  # Attach security list
  security_list_ids = [
    oci_core_security_list.public_sl.id
  ]
}

# Create Linux VM
resource "oci_core_instance" "linux_vm" {
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.E2.1.Micro"
  display_name        = "Fin-vm"

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
    hostname_label   = "finvm"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}
