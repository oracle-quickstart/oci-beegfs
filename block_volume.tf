
/*
Copyright © 2020, Oracle and/or its affiliates. All rights reserved.
The Universal Permissive License (UPL), Version 1.0
*/

/*
Metadata and Management Block Volume details
*/

resource "oci_core_volume" "metadata_blockvolume" {
  count               =  (var.metadata_use_shared_disk ? ((local.derived_metadata_server_node_count / 2)*var.metadata_server_disk_count)  : (local.derived_metadata_server_node_count * var.metadata_server_disk_count) )

  availability_domain = local.ad
  compartment_id      = var.compartment_ocid
  display_name        = "metadata-target${count.index % var.metadata_server_disk_count + 1}"
  size_in_gbs         = var.metadata_server_disk_size
  vpus_per_gb         = var.volume_type_vpus_per_gb_mapping[(var.metadata_server_disk_vpus_per_gb)]
}

resource "oci_core_volume_attachment" "metadata_blockvolume_attach" {
  attachment_type = "iscsi"
  count           = (local.derived_metadata_server_node_count * var.metadata_server_disk_count)
  instance_id = element(oci_core_instance.metadata_server.*.id, (var.metadata_use_shared_disk ? ((count.index % 2) + (floor(count.index/(var.metadata_server_disk_count*2))*2))   : count.index % local.derived_metadata_server_node_count),)
  volume_id = element(oci_core_volume.metadata_blockvolume.*.id, (var.metadata_use_shared_disk ? floor(count.index/2) : count.index))
  is_shareable = var.metadata_use_shared_disk ? true : false
  device       = var.volume_attach_device_mapping[(var.metadata_use_shared_disk ? floor(count.index/2) : count.index % var.metadata_server_disk_count)]

  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host    = element(
        oci_core_instance.metadata_server.*.private_ip,
        (var.metadata_use_shared_disk ? ((count.index % 2) + (floor(count.index/(var.metadata_server_disk_count*2))*2))   : count.index % local.derived_metadata_server_node_count)
      )

      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }

    inline = [
      "sudo -s bash -c 'set -x && iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}'",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic '",
      "sudo -s bash -c 'set -x && iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l '",
    ]
  }
}

/*
  Notify metadata server nodes that all block-attach is complete, so server nodes can continue with their rest of the instance setup logic in cloud-init.
*/
resource "null_resource" "notify_metadata_server_nodes_block_attach_complete" {
  depends_on = [ oci_core_volume_attachment.metadata_blockvolume_attach ]
  count      = local.derived_metadata_server_node_count
  provisioner "remote-exec" {
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.metadata_server.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.ssh.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.ssh.private_key_pem
    }
    inline = [
      "set -x",
      "sudo touch /tmp/block-attach.complete",
    ]
  }
}


resource "oci_core_volume" "management_blockvolume" {
  count               =  (var.management_high_availability ? ((local.derived_management_server_node_count / 2)*var.management_server_disk_count)  : (local.derived_management_server_node_count * var.management_server_disk_count) )
  availability_domain = local.ad
  compartment_id      = var.compartment_ocid
  display_name        = "management${count.index % local.derived_management_server_node_count + 1}-target${count.index % var.management_server_disk_count + 1}"
  size_in_gbs         = var.management_server_disk_size
  vpus_per_gb         = var.volume_type_vpus_per_gb_mapping[(var.management_server_disk_vpus_per_gb)]
}

resource "oci_core_volume_attachment" "management_blockvolume_attach" {
  attachment_type = "iscsi"
  count           = (local.derived_management_server_node_count * var.management_server_disk_count)
  instance_id = element(oci_core_instance.management_server.*.id, (var.management_high_availability ? ((count.index % 2) + (floor(count.index/(var.management_server_disk_count*2))*2))   : count.index % local.derived_management_server_node_count),)
  volume_id = element(oci_core_volume.management_blockvolume.*.id, (var.management_high_availability ? floor(count.index/2) : count.index))
  is_shareable = var.management_high_availability ? true : false
  device       = var.volume_attach_device_mapping[(var.management_high_availability ? floor(count.index/2) : count.index % var.management_server_disk_count)]

  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host    = element(
        oci_core_instance.management_server.*.private_ip,
        (var.management_high_availability ? ((count.index % 2) + (floor(count.index/(var.management_server_disk_count*2))*2))   : count.index % local.derived_management_server_node_count)
      )
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem
    }

    inline = [
      "sudo -s bash -c 'set -x && iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}'",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic '",
      "sudo -s bash -c 'set -x && iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l '",
    ]
  }
}


/*
  Notify management server nodes that all block-attach is complete, so  server nodes can continue with their rest of the instance setup logic in cloud-init.
*/
resource "null_resource" "notify_management_server_nodes_block_attach_complete" {
  depends_on = [ oci_core_volume_attachment.management_blockvolume_attach ]
  count      = local.derived_management_server_node_count
  provisioner "remote-exec" {
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
    inline = [
      "set -x",
      "sudo touch /tmp/block-attach.complete",
    ]
  }
}
