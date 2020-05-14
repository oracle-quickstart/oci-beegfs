/*
All network resources for this template
*/

variable "use_custom_name" {
  default = 0
}

resource "random_pet" "name" {
  length = 2
}

locals {
  cluster_name = var.use_custom_name ? var.cluster_name : random_pet.name.id
}

variable "cluster_name" {
  default = "Prototype"
}

resource "oci_core_vcn" "vcn" {
  count          = var.use_existing_vcn ? 0 : 1
  cidr_block     = var.vpc_cidr
  compartment_id = var.compartment_ocid
  display_name   = "${local.cluster_name}_VCN"
  dns_label      = "beegfs"
}

resource "oci_core_internet_gateway" "internet_gateway" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "${local.cluster_name}_internet_gateway"
  vcn_id         = oci_core_vcn.vcn[0].id
}

resource "oci_core_route_table" "pubic_route_table" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn[0].id
  display_name   = "${local.cluster_name}_public_route_table"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.internet_gateway[0].id
  }
}


resource "oci_core_nat_gateway" "nat_gateway" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn[0].id
  display_name   = "${local.cluster_name}_nat_gateway"
}


resource "oci_core_route_table" "private_route_table" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn[0].id
  display_name   = "${local.cluster_name}_private_route_table"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat_gateway[0].id
  }
}

resource "oci_core_security_list" "public_security_list" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name = "${local.cluster_name}_public_security_list"
  vcn_id = oci_core_vcn.vcn[0].id
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol = "6"
  }
  ingress_security_rules {
    tcp_options {
      max = 22
      min = 22
    }
    protocol = "6"
    source = "0.0.0.0/0"
  }
}

resource "oci_core_security_list" "private_security_list" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "${local.cluster_name}_private_security_list"
  vcn_id         = oci_core_vcn.vcn[0].id

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
  egress_security_rules {
    protocol    = "all"
    destination = var.vpc_cidr
  }
  ingress_security_rules  {
    protocol = "all"
    source   = var.vpc_cidr
  }
}


# Regional subnet - public
resource "oci_core_subnet" "public" {
  count             = var.use_existing_vcn ? 0 : 1
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  #display_name      = "${local.cluster_name}_public"
  display_name      = "Public-Subnet"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.vcn[0].id
  route_table_id    = oci_core_route_table.pubic_route_table[0].id
  security_list_ids = [oci_core_security_list.public_security_list[0].id]
  dhcp_options_id   = oci_core_vcn.vcn[0].default_dhcp_options_id
  dns_label         = "public"
}


# Regional subnet - private
resource "oci_core_subnet" "storage" {
  count                      = var.use_existing_vcn ? 0 : 1
  cidr_block                 = cidrsubnet(var.vpc_cidr, 8, count.index+1)
  #display_name               = "${local.cluster_name}_private_storage"
  display_name               = "Private-BeeGFS"
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.vcn[0].id
  route_table_id             = oci_core_route_table.private_route_table[0].id
  security_list_ids          = [oci_core_security_list.private_security_list[0].id]
  dhcp_options_id            = oci_core_vcn.vcn[0].default_dhcp_options_id
  prohibit_public_ip_on_vnic = "true"
  dns_label                  = "storage"
}


resource "oci_core_subnet" "fs" {
  count                      = var.use_existing_vcn ? 0 : 1
  cidr_block                 = cidrsubnet(var.vpc_cidr, 8, count.index+2)
  #display_name               = "${local.cluster_name}_private_fs"
  display_name               = "Private-Subnet"
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.vcn[0].id
  route_table_id             = oci_core_route_table.private_route_table[0].id
  security_list_ids          = [oci_core_security_list.private_security_list[0].id]
  dhcp_options_id            = oci_core_vcn.vcn[0].default_dhcp_options_id
  prohibit_public_ip_on_vnic = "true"
  dns_label                  = "fs"
}
