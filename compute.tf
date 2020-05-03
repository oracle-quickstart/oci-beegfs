
resource "tls_private_key" "ssh" {
  algorithm   = "RSA"
}

locals {
  storage_subnet_id = var.use_existing_vcn ? var.storage_subnet_id : element(concat(oci_core_subnet.storage.*.id, [""]), 0)
  fs_subnet_id      = var.use_existing_vcn ? var.fs_subnet_id : element(concat(oci_core_subnet.fs.*.id, [""]), 0)
  client_subnet_id  = var.use_existing_vcn ? var.fs_subnet_id : element(concat(oci_core_subnet.fs.*.id, [""]), 0)
  image_id          = (var.use_marketplace_image ? var.mp_listing_resource_id : var.images[var.region])
}


resource "oci_core_instance" "image_server" {
  count               = var.image_server_node_count
  availability_domain = local.ad
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.image_server_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.image_server_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.image_server_shape
  subnet_id           = local.storage_subnet_id

  source_details {
    source_type       = "image"
    source_id         = "ocid1.image.oc1.iad.aaaaaaaamspvs3amw74gzpux4tmn6gx4okfbe3lbf5ukeheed6va67usq7qq"
    # local.image_id
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
        file("${var.scripts_directory}/create_ha_image.sh"),
      )))}"
    }

  timeouts {
    create = "120m"
  }
}


resource "oci_core_instance" "management_server" {
  count               = local.derived_management_server_node_count
  availability_domain = local.ad
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.management_server_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.management_server_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.management_server_shape
  subnet_id           = local.storage_subnet_id

  source_details {
    source_type       = "image"
    # Image with DRBD compiled for OL7.7 kernel and PCS, Corosync, Pacemaker install
    source_id         = "ocid1.image.oc1.iad.aaaaaaaa4sdqnx63m74c6v24ch4wqrxy5duvhlzsms47fj2lxuianzc62wma"
    # local.image_id
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
        "management_server_filesystem_vnic_hostname_prefix=\"${local.management_server_filesystem_vnic_hostname_prefix}\"",
        "management_high_availability=\"${var.management_high_availability}\"",
        "management_vip_private_ip=\"${var.management_vip_private_ip}\"",
        "hacluster_user_password=\"${random_string.hacluster_user_password.result}\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/update_resolv_conf.sh"),
        file("${var.scripts_directory}/install_ha_w_image.sh"),
#        file("${var.scripts_directory}/install_management.sh")
      )))}"
    }

  timeouts {
    create = "120m"
  }
}

resource "null_resource" "move_HA_config_files" {
  depends_on = [ oci_core_instance.management_server ]
  count      = local.derived_management_server_node_count
  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/id_rsa"
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.management_server.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.ssh.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/opc/.ssh/id_rsa",
    ]
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.management_server.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.ssh.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    source        = "config"
    destination   = "/home/opc/"
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.management_server.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.ssh.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.ssh.private_key_pem
    }
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
        "management_high_availability=\"${var.management_high_availability}\"",
        "management_vip_private_ip=\"${var.management_vip_private_ip}\"",
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
        "management_high_availability=\"${var.management_high_availability}\"",
        "management_vip_private_ip=\"${var.management_vip_private_ip}\"",
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
        "client_node_count=\"${var.client_node_count}\"",
        "management_high_availability=\"${var.management_high_availability}\"",
        "management_vip_private_ip=\"${var.management_vip_private_ip}\"",
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


