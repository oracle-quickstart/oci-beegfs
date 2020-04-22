

output "SSH-login" {
value = <<END

        Bastion: ssh -i CHANGEME ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)}

        Management Server: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.management_server.*.private_ip, [""]), 0)}

        Metadata Server-1: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.metadata_server.*.private_ip, [""]), 0)}

        Storage Server-1: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.storage_server.*.private_ip, [""]), 0)}

        Client-1: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.client_node.*.private_ip, [""]), 0)}

END
}

output "Filesystem-Details" {
value = <<END

        BeeGFS Management Service Hostname: ${local.management_server_filesystem_vnic_hostname_prefix}1.${local.filesystem_subnet_domain_name}
        Mount Point:  ${var.beegfs_mount_point}
        Striping:  beegfs-ctl --setpattern --chunksize=${var.beegfs_stripe_size} --numtargets=4 ${var.beegfs_mount_point}
        storage_subnet_domain_name="${data.oci_core_subnet.storage_subnet.dns_label}.${data.oci_core_vcn.beegfs.dns_label}.oraclevcn.com"
        filesystem_subnet_domain_name="${data.oci_core_subnet.fs_subnet.dns_label}.${data.oci_core_vcn.beegfs.dns_label}.oraclevcn.com"
        vcn_domain_name="${data.oci_core_vcn.beegfs.dns_label}.oraclevcn.com"

END
}

