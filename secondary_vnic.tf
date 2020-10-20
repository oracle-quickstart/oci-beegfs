
resource "oci_core_vnic_attachment" "storage_server_secondary_vnic_attachment" {
  count = var.storage_server_node_count

  #Required
  create_vnic_details {
    #Required
    subnet_id = local.fs_subnet_id

    #Optional
    assign_public_ip = "false"
    display_name     = "${local.storage_server_filesystem_vnic_hostname_prefix}${format("%01d", count.index + 1)}"
    hostname_label   = "${local.storage_server_filesystem_vnic_hostname_prefix}${format("%01d", count.index + 1)}"

    # false is default value
    skip_source_dest_check = "false"
  }
  instance_id = element(oci_core_instance.storage_server.*.id, count.index)

  # set to 1, if you want to use 2nd physical NIC for this VNIC
  nic_index = (local.storage_server_dual_nics ? (local.storage_server_hpc_shape ? "0" : "1") : "0")

}

# TODO - add support for 4, 6, 8 ...OSS servers.
resource "oci_core_private_ip" "storage_vip_private_ip" {
  count = var.storage_use_shared_disk ? (local.derived_storage_server_node_count / 2) : (local.derived_storage_server_node_count)

  #Required
  vnic_id = element(concat(oci_core_vnic_attachment.storage_server_secondary_vnic_attachment.*.vnic_id,  [""]), (count.index*2))

  #Optional
  display_name = "oss-vip-${(count.index)}"
  hostname_label = "oss-vip-${(count.index)}"
  ip_address = (length(var.storage_vip_private_ip) > 0  ? element(split("," , var.storage_vip_private_ip), count.index) :  var.ha_vip_mapping[(1+(floor(local.derived_metadata_server_node_count/2)+(1+floor(count.index))))]  )
}


output "Storage-HA-VIP-Private-IP" {
value = <<END
   : ${join(",", concat(oci_core_private_ip.storage_vip_private_ip.*.ip_address, [""]))}
END
}


resource "oci_core_vnic_attachment" "metadata_server_secondary_vnic_attachment" {
  count = local.derived_metadata_server_node_count

  #Required
  create_vnic_details {
    #Required
    subnet_id = local.fs_subnet_id

    #Optional
    assign_public_ip = "false"
    display_name     = "${local.metadata_server_filesystem_vnic_hostname_prefix}${format("%01d", count.index + 1)}"
    hostname_label   = "${local.metadata_server_filesystem_vnic_hostname_prefix}${format("%01d", count.index + 1)}"

    # false is default value
    skip_source_dest_check = "false"
  }
  instance_id = element(oci_core_instance.metadata_server.*.id, count.index)

  # set to 1, if you want to use 2nd physical NIC for this VNIC
  nic_index = (local.metadata_server_dual_nics ? (local.metadata_server_hpc_shape ? "0" : "1") : "0")

}

resource "oci_core_private_ip" "metadata_vip_private_ip" {
  count = var.metadata_use_shared_disk ? (local.derived_metadata_server_node_count / 2) : (local.derived_metadata_server_node_count)
  #Required
  vnic_id = element(concat(oci_core_vnic_attachment.metadata_server_secondary_vnic_attachment.*.vnic_id,  [""]), (count.index*2))

  #Optional
  display_name = "mds-vip-${(count.index)}"
  hostname_label = "mds-vip-${(count.index)}"
  ip_address = (length(var.metadata_vip_private_ip) > 0  ? element(split("," , var.metadata_vip_private_ip), count.index) :  var.ha_vip_mapping[(1+(1+floor(count.index)))])
}

output "Metadata-HA-VIP-Private-IP" {
value = <<END
   : ${join(",", concat(oci_core_private_ip.metadata_vip_private_ip.*.ip_address, [""]))}
END
}

resource "oci_core_vnic_attachment" "management_server_secondary_vnic_attachment" {
  count = local.derived_management_server_node_count

  #Required
  create_vnic_details {
    #Required
    subnet_id = local.fs_subnet_id

    #Optional
    assign_public_ip = "false"
    display_name     = "${local.management_server_filesystem_vnic_hostname_prefix}${format("%01d", count.index + 1)}"
    hostname_label   = "${local.management_server_filesystem_vnic_hostname_prefix}${format("%01d", count.index + 1)}"

    # false is default value
    skip_source_dest_check = "false"
  }
  instance_id = element(oci_core_instance.management_server.*.id, count.index)

  # set to 1, if you want to use 2nd physical NIC for this VNIC
  nic_index = (local.management_server_dual_nics ? (local.management_server_hpc_shape ? "0" : "1") : "0")

}


resource "oci_core_private_ip" "management_vip_private_ip" {
    count = var.management_high_availability ? (local.derived_management_server_node_count / 2) : (local.derived_management_server_node_count)

    #Required
    vnic_id = element(concat(oci_core_vnic_attachment.management_server_secondary_vnic_attachment.*.vnic_id,  [""]), 0)

    #Optional
    display_name = "mgs-vip"
    hostname_label = "mgs-vip"
    ip_address = (length(var.management_vip_private_ip) > 0  ? var.management_vip_private_ip : (var.ha_vip_mapping[(1)]))
}

output "Management-HA-VIP-Private-IP" {
value = <<END
   : ${join(",", concat(oci_core_private_ip.management_vip_private_ip.*.ip_address, [""]))}
END
}


