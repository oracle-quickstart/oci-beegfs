# Gets a list of Availability Domains
data "oci_identity_availability_domains" "availability_domains" {
  compartment_id = "${var.compartment_ocid}"
}


data "oci_core_vcn" "beegfs" {
vcn_id = var.use_existing_vcn ? var.vcn_id : oci_core_virtual_network.beegfs[0].id
}

data "oci_core_subnet" "storage_subnet" {
subnet_id = var.use_existing_vcn ? var.storage_subnet_id : local.storage_subnet_id
}

data "oci_core_subnet" "fs_subnet" {
subnet_id = var.use_existing_vcn ? var.fs_subnet_id : local.fs_subnet_id
}

/*
data "oci_core_subnet" "client_subnet" {
subnet_id = var.use_existing_vcn ? : local.client_subnet_id
}
*/


