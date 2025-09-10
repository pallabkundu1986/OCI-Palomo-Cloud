variable "tenancy_ocid" {
  description = "The OCID of the tenancy"
  type        = string
}

variable "user_ocid" {
  description = "The OCID of the user calling the API"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the API key uploaded in OCI"
  type        = string
}

variable "private_key" {
  description = "Private key (PEM content) for OCI API authentication"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "OCI region (e.g., ap-hyderabad-1)"
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment OCID where resources will be created"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key to access the VM"
  type        = string
}

