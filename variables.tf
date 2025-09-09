variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "region" {}
variable "compartment_ocid" {}

variable "ssh_public_key" {
  description = "SSH public key to access the VM"
  type        = string
}

variable "private_key" {
  description = "Optional private key (if you are storing it in TF cloud)"
  type        = string
  default     = ""
}