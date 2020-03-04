
resource "tls_private_key" "public_private_key_pair" {
  algorithm   = "RSA"
}

resource "oci_core_instance" "management_server" {
  count               = var.management_server_node_count
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)]["name"]
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.ad_number - 1]["name"]
  availability_domain = "${local.ad}"

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.management_server_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.management_server_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = "${var.management_server_shape}"
  subnet_id           = "${oci_core_subnet.private.*.id[0]}"

  source_details {
    source_type = "image"
    source_id = "${var.images[var.region]}"
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.public_private_key_pair.public_key_openssh
      ]
    )
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "server_node_count=\"${var.management_server_node_count}\"",
        "server_hostname_prefix=\"${var.management_server_hostname_prefix}\"",
        "disk_size=\"${var.management_server_disk_size}\"",
        "disk_count=\"${var.management_server_disk_count}\"",
        "block_size=\"${var.beegfs_block_size}\"",
        "storage_subnet_domain_name=\"${local.storage_subnet_domain_name}\"",
        "filesystem_subnet_domain_name=\"${local.filesystem_subnet_domain_name}\"",
        "vcn_domain_name=\"${local.vcn_domain_name}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/install_management.sh")
      )))}"
    }

  timeouts {
    create = "120m"
  }

}


resource "oci_core_instance" "metadata_server" {
  count               = var.metadata_server_node_count
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)]["name"]
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.ad_number - 1]["name"]
  availability_domain = "${local.ad}"

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.metadata_server_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.metadata_server_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = "${var.metadata_server_shape}"
  subnet_id           = "${oci_core_subnet.private.*.id[0]}"

  source_details {
    source_type = "image"
    source_id = "${var.images[var.region]}"
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.public_private_key_pair.public_key_openssh
      ]
    )
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "server_node_count=\"${var.metadata_server_node_count}\"",
        "server_hostname_prefix=\"${var.metadata_server_hostname_prefix}\"",
        "disk_size=\"${var.metadata_server_disk_size}\"",
        "disk_count=\"${var.metadata_server_disk_count}\"",
        "management_server_filesystem_vnic_hostname_prefix=\"${local.management_server_filesystem_vnic_hostname_prefix}\"",
        "metadata_server_filesystem_vnic_hostname_prefix=\"${local.metadata_server_filesystem_vnic_hostname_prefix}\"",
        "block_size=\"${var.beegfs_block_size}\"",
        "storage_subnet_domain_name=\"${local.storage_subnet_domain_name}\"",
        "filesystem_subnet_domain_name=\"${local.filesystem_subnet_domain_name}\"",
        "vcn_domain_name=\"${local.vcn_domain_name}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/install_metadata.sh")
      )))}"
    }

  timeouts {
    create = "120m"
  }

}



resource "oci_core_instance" "storage_server" {
  count               = var.storage_server_node_count
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)]["name"]
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.ad_number - 1]["name"]
  availability_domain = "${local.ad}"

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.storage_server_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.storage_server_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = "${var.storage_server_shape}"
  subnet_id           = "${oci_core_subnet.private.*.id[0]}"

  source_details {
    source_type = "image"
    source_id = "${var.images[var.region]}"
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.public_private_key_pair.public_key_openssh
      ]
    )
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "server_node_count=\"${var.storage_server_node_count}\"",
        "disk_size=\"${var.storage_server_disk_size}\"",
        "disk_count=\"${var.storage_server_disk_count}\"",
        "management_server_filesystem_vnic_hostname_prefix=\"${local.management_server_filesystem_vnic_hostname_prefix}\"",
        "metadata_server_filesystem_vnic_hostname_prefix=\"${local.metadata_server_filesystem_vnic_hostname_prefix}\"",
        "storage_server_filesystem_vnic_hostname_prefix=\"${local.metadata_server_filesystem_vnic_hostname_prefix}\"",
        "block_size=\"${var.beegfs_block_size}\"",
        "storage_subnet_domain_name=\"${local.storage_subnet_domain_name}\"",
        "filesystem_subnet_domain_name=\"${local.filesystem_subnet_domain_name}\"",
        "vcn_domain_name=\"${local.vcn_domain_name}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/install_storage.sh")
      )))}"
    }

  timeouts {
    create = "120m"
  }

}


resource "oci_core_instance" "client_node" {
  count               = "${var.client_node_count}"
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)]["name"]
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.ad_number - 1]["name"]
  availability_domain = "${local.ad}"
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.client_node_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.client_node_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = "${var.client_node_shape}"
  subnet_id           = (local.storage_server_hpc_shape ? oci_core_subnet.private.*.id[0] : oci_core_subnet.privateb.*.id[0] )
  # subnet_id           =  oci_core_subnet.privateb.*.id[0]
  # (local.server_dual_nics ? oci_core_subnet.privateb.*.id[0] : oci_core_subnet.privateb.*.id[0])

  source_details {
    source_type = "image"
    source_id = "${var.images[var.region]}"
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.public_private_key_pair.public_key_openssh
      ]
    )
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "mount_point=\"${var.beegfs_mount_point}\"",
        "management_server_filesystem_vnic_hostname_prefix=\"${local.management_server_filesystem_vnic_hostname_prefix}\"",
        "storage_subnet_domain_name=\"${local.storage_subnet_domain_name}\"",
        "filesystem_subnet_domain_name=\"${local.filesystem_subnet_domain_name}\"",
        "vcn_domain_name=\"${local.vcn_domain_name}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/install_client.sh")
      )))}"
    }

  timeouts {
    create = "120m"
  }

}



/* bastion instances */
resource "oci_core_instance" "bastion" {
  count = "${var.bastion_node_count}"
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.ad_number - 1]["name"]
  availability_domain = "${local.ad}"
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.bastion_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = "${var.bastion_shape}"
  hostname_label      = "${var.bastion_hostname_prefix}${format("%01d", count.index+1)}"

  create_vnic_details {
    subnet_id              = "${oci_core_subnet.public.*.id[0]}"
    skip_source_dest_check = true
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.public_private_key_pair.public_key_openssh
      ]
    )
  }

  launch_options {
    network_type = "VFIO"
  }

  source_details {
    source_type = "image"
    source_id   = "${var.images[var.region]}"
  }
}


