variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key" {
  sensitive = true
}
variable "region" {}
variable "compartment_ocid" {}
variable "ssh_public_key" {}

