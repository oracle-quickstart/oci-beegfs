###
## Variables.tf for Terraform
## Defines variables and local values
###

variable "vpc_cidr" { default = "10.0.0.0/16" }


# One bastion node
variable "bastion" {
  type = "map"
  default = {
    shape      = "VM.Standard2.2"
    node_count = 1
    hostname_prefix = "bastion-"
  }
}

# BeeGFS Management (MGS) Server nodes variables
variable "management_server" {
  type = "map"
  default = {
    shape      = "VM.Standard2.2"
    node_count = 1
    disk_count = 1
    # Disk Configuration. size is in GB.
    disk_size = 50
    # Block volume elastic performance tier.  The number of volume performance units (VPUs) that will be applied to this volume per GB, representing the Block Volume service's elastic performance options. See https://docs.cloud.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm for more information.  Allowed values are 0, 10, and 20.  Recommended value is 10 for balanced performance and 20 to receive higher performance (IO throughput and IOPS) per GB.
    vpus_per_gb = "10"
    hostname_prefix = "mgs-server-"
    }
}

# BeeGFS Metadata (MDS) Server nodes variables
variable "metadata_server" {
  type = "map"
  default = {
    shape      = "VM.DenseIO2.16"
    node_count = 1
    # if disk_count > 1, then internally it creates a RAID0 of multiple disks.
    disk_count = 3
    # Disk Configuration. size is in GB.
    disk_size = 50
    # Block volume elastic performance tier.  The number of volume performance units (VPUs) that will be applied to this volume per GB, representing the Block Volume service's elastic performance options. See https://docs.cloud.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm for more information.  Allowed values are 0, 10, and 20.  Recommended value is 10 for balanced performance and 20 to receive higher performance (IO throughput and IOPS) per GB.
    vpus_per_gb = "10"
    hostname_prefix = "metadata-server-"
    }
}

# BeeGFS Object (OSS) Server nodes variables
variable "storage_server" {
  type = "map"
  default = {
    shape      = "VM.DenseIO2.24"
    node_count = 1
    # Disk are attached as JBOD,  no RAID, since Oracle Block Storage has replication in-built
    disk_count = 3
    # Disk Configuration. size is in GB.
    disk_size = 50
    # Block volume elastic performance tier.  The number of volume performance units (VPUs) that will be applied to this volume per GB, representing the Block Volume service's elastic performance options. See https://docs.cloud.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm for more information.  Allowed values are 0, 10, and 20.  Recommended value is 10 for balanced performance and 20 to receive higher performance (IO throughput and IOPS) per GB.
    vpus_per_gb = "10"
    hostname_prefix = "storage-server-"
    }
}


# Client nodes variables
variable "client_node" {
  type = "map"
  default = {
    shape      = "VM.Standard2.2"
    node_count = 1
    hostname_prefix = "client-"
    }
}

/*
  BeeGFS FS related variables
*/
variable "beegfs" {
  type = "map"
  default = {
    # Has to be in KB only. Use capital K, not lowercase k.
    block_size = "64K"
    mount_point = "/mnt/beegfs"
    # To be supported in future
    high_availability = false
  }
}


# This is currently used for the deployment.  
variable "AD" {
  default = "1"
}

################################################################
## Variables which in most cases do not require change by user
################################################################

variable "scripts_directory" { default = "../scripts" }

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}

variable "compartment_ocid" {}
variable "ssh_public_key" {}
variable "ssh_private_key" {}
variable "ssh_private_key_path" {}


variable "ssh_user" { default = "opc" }


locals {
  management_server_dual_nics = (length(regexall("^BM", var.management_server["shape"])) > 0 ? true : false)
  metadata_server_dual_nics = (length(regexall("^BM", var.metadata_server["shape"])) > 0 ? true : false)
  storage_server_dual_nics = (length(regexall("^BM", var.storage_server["shape"])) > 0 ? true : false)
  storage_subnet_domain_name=("${oci_core_subnet.private[0].dns_label}.${oci_core_virtual_network.beegfs.dns_label}.oraclevcn.com" )
  filesystem_subnet_domain_name=("${oci_core_subnet.privateb[0].dns_label}.${oci_core_virtual_network.beegfs.dns_label}.oraclevcn.com" )
  vcn_domain_name="${oci_core_virtual_network.beegfs.dns_label}.oraclevcn.com"
  management_server_filesystem_vnic_hostname_prefix = "${var.management_server["hostname_prefix"]}fs-vnic-"
  metadata_server_filesystem_vnic_hostname_prefix = "${var.metadata_server["hostname_prefix"]}fs-vnic-"
  storage_server_filesystem_vnic_hostname_prefix = "${var.storage_server["hostname_prefix"]}fs-vnic-"
}


variable "images" {
  type = map(string)
  default = {
    // https://docs.cloud.oracle.com/iaas/images/image/96ad11d8-2a4f-4154-b128-4d4510756983/
    // See https://docs.us-phoenix-1.oraclecloud.com/images/ or https://docs.cloud.oracle.com/iaas/images/
    // Oracle-provided image "CentOS-7-2018.08.15-0"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaavsw2452x5psvj7lzp7opjcpj3yx7or4swwzl5vrdydxtfv33sbmqa"
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaahhgvnnprjhfmzynecw2lqkwhztgibz5tcs3x4d5rxmbqcmesyqta"
    uk-london-1    = "ocid1.image.oc1.uk-london-1.aaaaaaaa3iltzfhdk5m6f27wcuw4ttcfln54twkj66rsbn52yemg3gi5pkqa"
    us-phoenix-1   = "ocid1.image.oc1.phx.aaaaaaaaa2ph5vy4u7vktmf3c6zemhlncxkomvay2afrbw5vouptfbydwmtq"
  }
}

// See https://docs.cloud.oracle.com/en-us/iaas/images/image/0a72692a-bdbb-46fc-b17b-6e0a3fedeb23/
// Oracle-provided image "Oracle-Linux-7.7-2020.01.28-0"
// Kernel Version: 4.14.35-1902.10.4.el7uek.x86_64
variable "imagesOL" {
  type = "map"
  default = {
    ap-melbourne-1 = "ocid1.image.oc1.ap-melbourne-1.aaaaaaaa3fvafraincszwi36zv2oeangeitnnj7svuqjbm2agz3zxhzozadq"
    ap-mumbai-1 = "ocid1.image.oc1.ap-mumbai-1.aaaaaaaabyd7swhvmsttpeejgksgx3faosizrfyeypdmqdghgn7wzed26l3q"
    ap-osaka-1 = "ocid1.image.oc1.ap-osaka-1.aaaaaaaa7eec33y25cvvanoy5kf5udu3qhheh3kxu3dywblwqerui3u72nua"
    ap-seoul-1 = "ocid1.image.oc1.ap-seoul-1.aaaaaaaai233ko3wxveyibsjf5oew4njzhmk34e42maetaynhbljbvkzyqqa"
    ap-sydney-1 = "ocid1.image.oc1.ap-sydney-1.aaaaaaaaeb3c3kmd3yfaqc3zu6ko2q6gmg6ncjvvc65rvm3aqqzi6xl7hluq"
    ap-tokyo-1 = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaattpocc2scb7ece7xwpadvo4c5e7iuyg7p3mhbm554uurcgnwh5cq"
    ca-toronto-1 = "ocid1.image.oc1.ca-toronto-1.aaaaaaaa4u2x3aofmhogbw6xsckha6qdguiwqvh5ibnbuskfo2k6e3jhdtcq"
    eu-amsterdam-1 = "ocid1.image.oc1.eu-amsterdam-1.aaaaaaaan5tbzuvtyd5lwxj66zxc7vzmpvs5axpcxyhoicbr6yxgw2s7nqvq"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaa4xluwijh66fts4g42iw7gnixntcmns73ei3hwt2j7lihmswkrada"
    eu-zurich-1 = "ocid1.image.oc1.eu-zurich-1.aaaaaaaagj2saw4bisxyfe5joary52bpggvpdeopdocaeu2khpzte6whpksq"
    me-jeddah-1 = "ocid1.image.oc1.me-jeddah-1.aaaaaaaaczhhskrjad7l3vz2u3zyrqs4ys4r57nrbxgd2o7mvttzm4jryraa"
    sa-saopaulo-1 = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaabm464lilgh2nqw2vpshvc2cgoeuln5wgrfji5dafbiyi4kxtrmwa"
    uk-gov-london-1 = "ocid1.image.oc4.uk-gov-london-1.aaaaaaaa3badeua232q6br2srcdbjb4zyqmmzqgg3nbqwvp3ihjfac267glq"
    uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaa2jxzt25jti6n64ks3hqbqbxlbkmvel6wew5dc2ms3hk3d3bdrdoa"
    us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaamspvs3amw74gzpux4tmn6gx4okfbe3lbf5ukeheed6va67usq7qq"
    us-langley-1 = "ocid1.image.oc2.us-langley-1.aaaaaaaawzkqcffiqlingild6jqdnlacweni7ea2rm6kylar5tfc3cd74rcq"
    us-luke-1 = "ocid1.image.oc2.us-luke-1.aaaaaaaawo4qfu7ibanw2zwefm7q7hqpxsvzrmza4uwfqvtqg2quk6zghqia"
    us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaamff6sipozlita6555ypo5uyqo2udhjqwtrml2trogi6vnpgvet5q"
  }
}
