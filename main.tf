##########################################
# Lookup Oracle Linux Image
##########################################
data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = "VM.Standard.E2.1.Micro"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

##########################################
# Lookup Availability Domains
##########################################
data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.tenancy_ocid
}

##########################################
# VM Instance (Only)
##########################################
resource "oci_core_instance" "linux_vm" {
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.E2.1.Micro"
  display_name        = "Fin-vm"

  create_vnic_details {
    subnet_id        = var.subnet_ocid
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