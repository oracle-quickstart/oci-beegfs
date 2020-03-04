

output "SSH-login" {
value = <<END

        Bastion: ssh -i CHANGEME ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]}

        Management Server: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]} -W %h:%p %r" ${var.ssh_user}@${oci_core_instance.management_server.*.private_ip[0]}

        Metadata Server-1: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]} -W %h:%p %r" ${var.ssh_user}@${oci_core_instance.metadata_server.*.private_ip[0]}

        Storage Server-1: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]} -W %h:%p %r" ${var.ssh_user}@${oci_core_instance.storage_server.*.private_ip[0]}

        Client-1: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]} -W %h:%p %r" ${var.ssh_user}@${oci_core_instance.client_node.*.private_ip[0]}

END
}



