resource "oci_core_instance" "drbd_quorum" {
  count               = 1
  availability_domain = local.ad
  fault_domain        = "FAULT-DOMAIN-${(count.index%3)+3}"
  compartment_id      = var.compartment_ocid
  display_name        = "drbd-quorum-${format("%01d", count.index+1)}"
  hostname_label      = "drbd-quorum-${format("%01d", count.index+1)}"
  shape               = "VM.Standard2.2"
  subnet_id           = local.storage_subnet_id

  source_details {
    source_type       = "image"
    # Image with DRBD compiled for OL7.7 kernel and PCS, Corosync, Pacemaker install
    source_id         = local.management_image_id
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
        "server_hostname_prefix=\"${var.management_server_hostname_prefix}\"",
        "storage_subnet_domain_name=\"${local.storage_subnet_domain_name}\"",
        "filesystem_subnet_domain_name=\"${local.filesystem_subnet_domain_name}\"",
        "vcn_domain_name=\"${local.vcn_domain_name}\"",
        "management_server_filesystem_vnic_hostname_prefix=\"${local.management_server_filesystem_vnic_hostname_prefix}\"",
        "management_high_availability=\"${var.management_high_availability}\"",
        "management_vip_private_ip=\"${var.management_vip_private_ip}\"",
        "quorum_hostname=\"drbd-quorum-1\"",
        file("${var.scripts_directory}/firewall.sh"),
        file("${var.scripts_directory}/update_resolv_conf.sh"),
#       file("${var.scripts_directory}/configure_vnics.sh"),
        file("${var.scripts_directory}/install_drbd_quorum.sh"),
      )))}"
    }

  timeouts {
    create = "120m"
  }
}

resource "null_resource" "move_HA_config_files_to_quorum" {
  depends_on = [ oci_core_instance.drbd_quorum ]
  count      = 1
  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/id_rsa"
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.drbd_quorum.*.private_ip, count.index)
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
        host                = element(oci_core_instance.drbd_quorum.*.private_ip, count.index)
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
        host                = element(oci_core_instance.drbd_quorum.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.ssh.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.ssh.private_key_pem
    }
  }

}


