

locals {
  ssh_private_key_path="/Users/pvaldria/.ssh/gg_id_rsa"
}

output "SSH-login" {
value = <<END

        CHANGEME: ${local.ssh_private_key_path} with your SSH Private Key in the commands below.

        Bastion: ssh -i ${local.ssh_private_key_path} ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)}

        Management Server-1: ssh -i ${local.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${local.ssh_private_key_path} -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.management_server.*.private_ip, [""]), 0)}

        Metadata Server-1: ssh -i ${local.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${local.ssh_private_key_path} -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.metadata_server.*.private_ip, [""]), 0)}

        Storage Server-1: ssh -i ${local.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${local.ssh_private_key_path} -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.storage_server.*.private_ip, [""]), 0)}

        Client-1: ssh -i ${local.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${local.ssh_private_key_path} -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.client_node.*.private_ip, [""]), 0)}

END
}

output "Filesystem-Details" {
value = <<END

        BeeGFS Management Service Hostname: ${local.management_server_filesystem_vnic_hostname_prefix}1.${local.filesystem_subnet_domain_name}
        Mount Point:  ${var.beegfs_mount_point}
        Striping:  beegfs-ctl --setpattern --chunksize=${var.beegfs_stripe_size} --numtargets=4 ${var.beegfs_mount_point}
        storage_subnet_domain_name="${data.oci_core_subnet.storage_subnet.dns_label}.${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com"
        filesystem_subnet_domain_name="${data.oci_core_subnet.fs_subnet.dns_label}.${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com"
        vcn_domain_name="${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com"

END
}

output "Full-list-of-Servers" {
value = <<END

        Bastion: ${join(",", oci_core_instance.bastion.*.public_ip)}
        MGS: ${join(",", oci_core_instance.management_server.*.private_ip)}
        MDS: ${join(",", oci_core_instance.metadata_server.*.private_ip)}
        OSS: ${join(",", oci_core_instance.storage_server.*.private_ip)}
        Client: ${join(",", oci_core_instance.client_node.*.private_ip)}

END
}
