resource "oci_core_instance" "management_server" {
  count               = var.management_server["node_count"]
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)]["name"]
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1]["name"]

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.management_server["hostname_prefix"]}${format("%01d", count.index+1)}"
  hostname_label      = "${var.management_server["hostname_prefix"]}${format("%01d", count.index+1)}"
  shape               = "${var.management_server["shape"]}"
  subnet_id           = "${oci_core_subnet.private.*.id[0]}"

  source_details {
    source_type = "image"
    source_id = "${var.images[var.region]}"
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "gluster_yum_release=\"${var.gluster_ol_repo_mapping[var.beegfs["version"]]}\"",
        "server_node_count=\"${var.management_server["node_count"]}\"",
        "server_hostname_prefix=\"${var.management_server["hostname_prefix"]}\"",
"disk_size=\"${var.management_server["disk_size"]}\"",
"disk_count=\"${var.management_server["disk_count"]}\"",
"num_of_disks_in_brick=\"${var.management_server["num_of_disks_in_brick"]}\"",
"replica=\"${var.beegfs["replica"]}\"",
        "volume_types=\"${var.beegfs["volume_types"]}\"",
        "block_size=\"${var.beegfs["block_size"]}\"",
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
  count               = var.metadata_server["node_count"]
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)]["name"]
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1]["name"]

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.metadata_server["hostname_prefix"]}${format("%01d", count.index+1)}"
  hostname_label      = "${var.metadata_server["hostname_prefix"]}${format("%01d", count.index+1)}"
  shape               = "${var.metadata_server["shape"]}"
  subnet_id           = "${oci_core_subnet.private.*.id[0]}"

  source_details {
    source_type = "image"
    source_id = "${var.images[var.region]}"
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "gluster_yum_release=\"${var.gluster_ol_repo_mapping[var.beegfs["version"]]}\"",
        "server_node_count=\"${var.metadata_server["node_count"]}\"",
        "server_hostname_prefix=\"${var.metadata_server["hostname_prefix"]}\"",
"disk_size=\"${var.metadata_server["disk_size"]}\"",
"disk_count=\"${var.metadata_server["disk_count"]}\"",
"num_of_disks_in_brick=\"${var.metadata_server["num_of_disks_in_brick"]}\"",
"management_server_filesystem_vnic_hostname_prefix=\"${local.management_server_filesystem_vnic_hostname_prefix}\"",
"metadata_server_filesystem_vnic_hostname_prefix=\"${local.metadata_server_filesystem_vnic_hostname_prefix}\"",
"replica=\"${var.beegfs["replica"]}\"",
        "volume_types=\"${var.beegfs["volume_types"]}\"",
        "block_size=\"${var.beegfs["block_size"]}\"",
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
  count               = var.storage_server["node_count"]
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)]["name"]
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1]["name"]

  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.storage_server["hostname_prefix"]}${format("%01d", count.index+1)}"
  hostname_label      = "${var.storage_server["hostname_prefix"]}${format("%01d", count.index+1)}"
  shape               = "${var.storage_server["shape"]}"
  subnet_id           = "${oci_core_subnet.private.*.id[0]}"

  source_details {
    source_type = "image"
    source_id = "${var.images[var.region]}"
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "gluster_yum_release=\"${var.gluster_ol_repo_mapping[var.beegfs["version"]]}\"",
        "server_node_count=\"${var.storage_server["node_count"]}\"",
        "server_hostname_prefix=\"${var.storage_server["hostname_prefix"]}\"",
"disk_size=\"${var.storage_server["disk_size"]}\"",
"disk_count=\"${var.storage_server["disk_count"]}\"",
"management_server_filesystem_vnic_hostname_prefix=\"${local.management_server_filesystem_vnic_hostname_prefix}\"",
"metadata_server_filesystem_vnic_hostname_prefix=\"${local.metadata_server_filesystem_vnic_hostname_prefix}\"",
"storage_server_filesystem_vnic_hostname_prefix=\"${local.metadata_server_filesystem_vnic_hostname_prefix}\"",
"num_of_disks_in_brick=\"${var.storage_server["num_of_disks_in_brick"]}\"",
"replica=\"${var.beegfs["replica"]}\"",
        "volume_types=\"${var.beegfs["volume_types"]}\"",
        "block_size=\"${var.beegfs["block_size"]}\"",
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
  count               = "${var.client_node["node_count"]}"
  #availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[(count.index%3)]["name"]
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1]["name"]  
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.client_node["hostname_prefix"]}${format("%01d", count.index+1)}"
  hostname_label      = "${var.client_node["hostname_prefix"]}${format("%01d", count.index+1)}"
  shape               = "${var.client_node["shape"]}"
  # Always assume client uses subnet which is 2nd VNIC subnet of file servers.
  subnet_id           =  oci_core_subnet.privateb.*.id[0]
  # (local.server_dual_nics ? oci_core_subnet.privateb.*.id[0] : oci_core_subnet.privateb.*.id[0])

  source_details {
    source_type = "image"
    source_id = "${var.images[var.region]}"
  }

  launch_options {
    network_type = "VFIO"
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
        "gluster_yum_release=\"${var.gluster_ol_repo_mapping[var.beegfs["version"]]}\"",
        "mount_point=\"${var.beegfs["mount_point"]}\"",
        "server_hostname_prefix=\"${var.storage_server["hostname_prefix"]}\"",
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
  count = "${var.bastion["node_count"]}"
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1]["name"]
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "${var.bastion["hostname_prefix"]}${format("%01d", count.index+1)}"
  shape               = "${var.bastion["shape"]}"
  hostname_label      = "${var.bastion["hostname_prefix"]}${format("%01d", count.index+1)}"

  create_vnic_details {
    subnet_id              = "${oci_core_subnet.public.*.id[0]}"
    skip_source_dest_check = true
  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
  }

  launch_options {
    network_type = "VFIO"
  }

  source_details {
    source_type = "image"
    source_id   = "${var.images[var.region]}"
  }
}


