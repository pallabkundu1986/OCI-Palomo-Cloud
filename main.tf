data "oci_core_images" "oracle_linux" {
  compartment_id = palomocloud
  operating_system = "Oracle Linux"
  operating_system_version = "9"
  shape = "VM.Standard.E2.1.Micro"
  
    tags = {
    Name = "Fin_vm"
  }
}
