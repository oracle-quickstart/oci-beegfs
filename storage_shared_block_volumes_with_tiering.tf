/*
Copyright © 2020, Oracle and/or its affiliates. All rights reserved.
The Universal Permissive License (UPL), Version 1.0
*/

resource "oci_core_volume" "storage_blockvolume" {
  count               =  (var.storage_use_shared_disk ? ((local.derived_storage_server_node_count / 2)*local.all_block_count)  :  0 )
  availability_domain = local.ad
  compartment_id      = var.compartment_ocid
  display_name        = "storage-target${count.index % local.all_block_count + 1}"
  size_in_gbs         = ( var.storage_tier_1_disk_type == "Local_NVMe_SSD" ? ((count.index % local.all_block_count) <  var.storage_tier_2_disk_count ? var.storage_tier_2_disk_size  :  (count.index % local.all_block_count)  <  (var.storage_tier_2_disk_count + var.storage_tier_3_disk_count) ? var.storage_tier_3_disk_size : (count.index % local.all_block_count)  <  (var.storage_tier_2_disk_count + var.storage_tier_3_disk_count + var.storage_tier_4_disk_count) ? var.storage_tier_4_disk_size : -1 ) : ((count.index % local.all_block_count)  <  var.storage_tier_1_disk_count ? var.storage_tier_1_disk_size  :  (count.index % local.all_block_count)  <  (var.storage_tier_1_disk_count + var.storage_tier_2_disk_count) ? var.storage_tier_2_disk_size : (count.index % local.all_block_count)  <  (var.storage_tier_1_disk_count + var.storage_tier_2_disk_count + var.storage_tier_3_disk_count) ? var.storage_tier_3_disk_size : var.storage_tier_4_disk_size   )  )
  vpus_per_gb         = ( var.storage_tier_1_disk_type == "Local_NVMe_SSD" ? ((count.index % local.all_block_count) <  var.storage_tier_2_disk_count ? var.volume_type_vpus_per_gb_mapping[(var.storage_tier_2_disk_type)]  :  (count.index % local.all_block_count)  <  (var.storage_tier_2_disk_count + var.storage_tier_3_disk_count) ? var.volume_type_vpus_per_gb_mapping[(var.storage_tier_3_disk_type)] : (count.index % local.all_block_count)  <  (var.storage_tier_2_disk_count + var.storage_tier_3_disk_count + var.storage_tier_4_disk_count) ? var.volume_type_vpus_per_gb_mapping[(var.storage_tier_4_disk_type)] : -1 ) : ((count.index % local.all_block_count)  <  var.storage_tier_1_disk_count ? var.volume_type_vpus_per_gb_mapping[(var.storage_tier_1_disk_type)]  :  (count.index % local.all_block_count)  <  (var.storage_tier_1_disk_count + var.storage_tier_2_disk_count) ? var.volume_type_vpus_per_gb_mapping[(var.storage_tier_2_disk_type)] : (count.index % local.all_block_count)  <  (var.storage_tier_1_disk_count + var.storage_tier_2_disk_count + var.storage_tier_3_disk_count) ? var.volume_type_vpus_per_gb_mapping[(var.storage_tier_3_disk_type)] : var.volume_type_vpus_per_gb_mapping[(var.storage_tier_4_disk_type)]  )  )
}

resource "oci_core_volume_attachment" "storage_blockvolume_attach" {
  attachment_type = "iscsi"
  count           = var.storage_use_shared_disk ? (local.derived_storage_server_node_count * local.all_block_count) : 0
  instance_id = element(oci_core_instance.storage_server.*.id, (var.storage_use_shared_disk ? ((count.index % 2) + (floor(count.index/(local.all_block_count*2))*2))   : count.index % local.derived_storage_server_node_count),)
  volume_id = element(oci_core_volume.storage_blockvolume.*.id, (var.storage_use_shared_disk ? floor(count.index/2) : count.index))
  is_shareable = var.storage_use_shared_disk ? true : false
  device       = var.volume_attach_device_mapping[((var.storage_use_shared_disk ? floor(count.index/2) : count.index % local.all_block_count))]

  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host    = element(
        oci_core_instance.storage_server.*.private_ip,
        #count.index % var.storage_server_node_count,
        #count.index % local.derived_storage_server_node_count,
        (var.storage_use_shared_disk ? ((count.index % 2) + (floor(count.index/(local.all_block_count*2))*2))   : count.index % local.derived_storage_server_node_count)
      )
      #var.storage_tier_1_disk_count
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
  Notify storage server nodes that all block-attach is complete, so server nodes can continue with their rest of the instance setup logic in cloud-init.
*/
resource "null_resource" "notify_ha_storage_server_nodes_block_attach_complete" {
  depends_on = [ oci_core_volume_attachment.storage_blockvolume_attach ]
  count      = var.storage_use_shared_disk ? local.derived_storage_server_node_count : 0
  provisioner "remote-exec" {
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.storage_server.*.private_ip, count.index)
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


