
resource "tls_private_key" "ssh" {
  algorithm   = "RSA"
}

locals {
  storage_subnet_id = var.use_existing_vcn ? var.storage_subnet_id : element(concat(oci_core_subnet.storage.*.id, [""]), 0)
  fs_subnet_id      = var.use_existing_vcn ? var.fs_subnet_id : element(concat(oci_core_subnet.fs.*.id, [""]), 0)
  client_subnet_id  = var.use_existing_vcn ? var.fs_subnet_id : element(concat(oci_core_subnet.fs.*.id, [""]), 0)
  image_id          = (var.use_marketplace_image ? var.mp_listing_resource_id : var.images[var.region])
}


resource "oci_core_instance" "management_server" {
  count               = var.management_server_node_count
  availability_domain = local.ad
  #fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.management_server_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.management_server_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.management_server_shape
  subnet_id           = local.storage_subnet_id

  source_details {
    source_type       = "image"
    source_id         = local.image_id
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.ssh.public_key_openssh
      ]
    )
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "server_node_count=\"${var.management_server_node_count}\"",
        "server_hostname_prefix=\"${var.management_server_hostname_prefix}\"",
        "disk_size=\"${var.management_server_disk_size}\"",
        "disk_count=\"${var.management_server_disk_count}\"",
        "storage_subnet_domain_name=\"${local.storage_subnet_domain_name}\"",
        "filesystem_subnet_domain_name=\"${local.filesystem_subnet_domain_name}\"",
        "vcn_domain_name=\"${local.vcn_domain_name}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/update_resolv_conf.sh"),
        file("${var.scripts_directory}/install_management.sh")
      )))}"
    }

  timeouts {
    create = "120m"
  }

}


resource "oci_core_instance" "metadata_server" {
  count               = var.metadata_server_node_count
  availability_domain = local.ad
  #fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.metadata_server_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.metadata_server_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.metadata_server_shape
  subnet_id           = local.storage_subnet_id

  source_details {
    source_type = "image"
    source_id   = local.image_id
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.ssh.public_key_openssh
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
        "storage_subnet_domain_name=\"${local.storage_subnet_domain_name}\"",
        "filesystem_subnet_domain_name=\"${local.filesystem_subnet_domain_name}\"",
        "vcn_domain_name=\"${local.vcn_domain_name}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/update_resolv_conf.sh"),
        file("${var.scripts_directory}/install_metadata.sh"),
        file("${var.scripts_directory}/metadata_tuning.sh")
      )))}"
    }

  timeouts {
    create = "120m"
  }

}



resource "oci_core_instance" "storage_server" {
  count               = var.storage_server_node_count
  availability_domain = local.ad
  #fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.storage_server_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.storage_server_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.storage_server_shape
  subnet_id           = local.storage_subnet_id

  source_details {
    source_type = "image"
    source_id   = local.image_id
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.ssh.public_key_openssh
      ]
    )
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "server_node_count=\"${var.storage_server_node_count}\"",
        "management_server_filesystem_vnic_hostname_prefix=\"${local.management_server_filesystem_vnic_hostname_prefix}\"",
        "metadata_server_filesystem_vnic_hostname_prefix=\"${local.metadata_server_filesystem_vnic_hostname_prefix}\"",
        "storage_server_filesystem_vnic_hostname_prefix=\"${local.storage_server_filesystem_vnic_hostname_prefix}\"",
        "storage_subnet_domain_name=\"${local.storage_subnet_domain_name}\"",
        "filesystem_subnet_domain_name=\"${local.filesystem_subnet_domain_name}\"",
        "vcn_domain_name=\"${local.vcn_domain_name}\"",
        "storage_tier_1_disk_type=\"${var.storage_tier_1_disk_type}\"",
        "storage_tier_1_disk_count=\"${var.storage_tier_1_disk_count}\"",
        "storage_tier_1_disk_size=\"${var.storage_tier_1_disk_size}\"",
        "storage_tier_2_disk_type=\"${var.storage_tier_2_disk_type}\"",
        "storage_tier_2_disk_count=\"${var.storage_tier_2_disk_count}\"",
        "storage_tier_2_disk_size=\"${var.storage_tier_2_disk_size}\"",
        "storage_tier_3_disk_type=\"${var.storage_tier_3_disk_type}\"",
        "storage_tier_3_disk_count=\"${var.storage_tier_3_disk_count}\"",
        "storage_tier_3_disk_size=\"${var.storage_tier_3_disk_size}\"",
        "storage_tier_4_disk_type=\"${var.storage_tier_4_disk_type}\"",
        "storage_tier_4_disk_count=\"${var.storage_tier_4_disk_count}\"",
        "storage_tier_4_disk_size=\"${var.storage_tier_4_disk_size}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/update_resolv_conf.sh"),
        file("${var.scripts_directory}/install_storage.sh"),
        file("${var.scripts_directory}/storage_tuning.sh"),
      )))}"
    }

  timeouts {
    create = "120m"
  }

}


resource "oci_core_instance" "client_node" {
  count               = var.client_node_count
  availability_domain = local.ad
  #fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.client_node_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.client_node_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.client_node_shape
  subnet_id           = local.client_subnet_id

  source_details {
    source_type = "image"
    source_id   = local.image_id
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.ssh.public_key_openssh
      ]
    )
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "stripe_size=\"${var.beegfs_stripe_size}\"",
        "mount_point=\"${var.beegfs_mount_point}\"",
        "management_server_filesystem_vnic_hostname_prefix=\"${local.management_server_filesystem_vnic_hostname_prefix}\"",
        "storage_subnet_domain_name=\"${local.storage_subnet_domain_name}\"",
        "filesystem_subnet_domain_name=\"${local.filesystem_subnet_domain_name}\"",
        "vcn_domain_name=\"${local.vcn_domain_name}\"",
        "management_server_node_count=\"${var.management_server_node_count}\"",
        "metadata_server_node_count=\"${var.metadata_server_node_count}\"",
        "storage_server_node_count=\"${var.storage_server_node_count}\"",
        "metadata_server_filesystem_vnic_hostname_prefix=\"${local.metadata_server_filesystem_vnic_hostname_prefix}\"",
        "storage_server_filesystem_vnic_hostname_prefix=\"${local.storage_server_filesystem_vnic_hostname_prefix}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/install_client.sh"),
        file("${var.scripts_directory}/update_etc_hosts.sh"),
      )))}"
    }

  timeouts {
    create = "120m"
  }

}


locals {
  bastion_subnet_id = var.use_existing_vcn ? var.bastion_subnet_id : element(concat(oci_core_subnet.public.*.id, [""]), 0)
}

/* bastion instances */
resource "oci_core_instance" "bastion" {
  count = var.bastion_node_count
  availability_domain = local.ad
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.bastion_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.bastion_shape
  hostname_label      = "${var.bastion_hostname_prefix}${format("%01d", count.index+1)}"

  create_vnic_details {
    subnet_id              = local.bastion_subnet_id
    skip_source_dest_check = true
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.ssh.public_key_openssh
      ]
    )
  }

  source_details {
    source_type = "image"
    source_id   = var.images[var.region]
  }


  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/cluster.key"
    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/id_rsa"
    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

}


