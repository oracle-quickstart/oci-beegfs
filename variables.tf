###
## Variables.tf for Terraform
## Defines variables and local values
###

variable "vpc_cidr" { default = "10.0.0.0/16" }


variable bastion_shape { default = "VM.Standard2.2" }
variable bastion_node_count { default = 1 }
variable bastion_hostname_prefix { default = "bastion-" }


# BeeGFS Management (MGS) Server nodes variables
variable management_server_shape { default = "VM.Standard2.2" }
variable management_server_node_count { default = 1 }
variable management_server_disk_count { default = 1 }
variable management_server_disk_size { default = 50 }
# Block volume elastic performance tier.  The number of volume performance units (VPUs) that will be applied to this volume per GB, representing the Block Volume service's elastic performance options. See https://docs.cloud.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm for more information.  Allowed values are 0, 10, and 20.  Recommended value is 10 for balanced performance and 20 to receive higher performance (IO throughput and IOPS) per GB.
variable management_server_disk_vpus_per_gb { default = "10" }
variable management_server_hostname_prefix { default = "mgs-server-" }



# BeeGFS Metadata (MDS) Server nodes variables
variable metadata_server_shape { default = "VM.Standard2.2" }
variable metadata_server_node_count { default = 1 }
# if disk_count > 1, then internally it creates a RAID0 of multiple disks.
variable metadata_server_disk_count { default = 2 }
variable metadata_server_disk_size { default = 50 }
# Block volume elastic performance tier.  The number of volume performance units (VPUs) that will be applied to this volume per GB, representing the Block Volume service's elastic performance options. See https://docs.cloud.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm for more information.  Allowed values are 0, 10, and 20.  Recommended value is 10 for balanced performance and 20 to receive higher performance (IO throughput and IOPS) per GB.
variable metadata_server_disk_vpus_per_gb { default = "10" }
variable metadata_server_hostname_prefix { default = "metadata-server-" }



# BeeGFS Stoarage/Object (OSS) Server nodes variables
variable storage_server_shape { default = "VM.Standard2.2" }
variable storage_server_node_count { default = 2 }
# if disk_count > 1, then internally it creates a RAID0 of multiple disks.
variable storage_server_disk_count { default = 3 }
variable storage_server_disk_size { default = 50 }
# Block volume elastic performance tier.  The number of volume performance units (VPUs) that will be applied to this volume per GB, representing the Block Volume service's elastic performance options. See https://docs.cloud.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm for more information.  Allowed values are 0, 10, and 20.  Recommended value is 10 for balanced performance and 20 to receive higher performance (IO throughput and IOPS) per GB.
variable storage_server_disk_vpus_per_gb { default = "10" }
variable storage_server_hostname_prefix { default = "storage-server-" }

# Client nodes variables
variable client_node_shape { default = "VM.Standard2.2" }
variable client_node_count { default = 1 }
variable client_node_hostname_prefix { default = "client-" }



# BeeGFS FS related variables
# Has to be in kilobytes only. Only numerical value.
variable beegfs_block_size { default = "64" }
variable beegfs_mount_point { default = "/mnt/beegfs" }
# To be supported in future
variable beegfs_high_availability { default = false }


# This is currently used for the deployment.  
variable "ad_number" {
  default = "1"
}

################################################################
## Variables which in most cases do not require change by user
################################################################

variable "scripts_directory" { default = "scripts" }

variable "tenancy_ocid" {}
variable "region" {}

variable "compartment_ocid" {
  description = "Compartment where infrastructure resources will be created"
}
variable "ssh_public_key" {
  description = "SSH Public Key"
}


variable "ssh_user" { default = "opc" }


locals {
  management_server_dual_nics = (length(regexall("^BM", var.management_server_shape)) > 0 ? true : false)
  metadata_server_dual_nics = (length(regexall("^BM", var.metadata_server_shape)) > 0 ? true : false)
  storage_server_dual_nics = (length(regexall("^BM", var.storage_server_shape)) > 0 ? true : false)
  storage_server_hpc_shape = (length(regexall("HPC2", var.storage_server_shape)) > 0 ? true : false)
  storage_subnet_domain_name=("${oci_core_subnet.private[0].dns_label}.${oci_core_virtual_network.beegfs.dns_label}.oraclevcn.com" )
  filesystem_subnet_domain_name=(length(regexall("HPC2", var.storage_server_shape)) > 0 ? "${oci_core_subnet.private[0].dns_label}.${oci_core_virtual_network.beegfs.dns_label}.oraclevcn.com" : "${oci_core_subnet.privateb[0].dns_label}.${oci_core_virtual_network.beegfs.dns_label}.oraclevcn.com" )
  vcn_domain_name="${oci_core_virtual_network.beegfs.dns_label}.oraclevcn.com"
  management_server_filesystem_vnic_hostname_prefix = "${var.management_server_hostname_prefix}fs-vnic-"
  metadata_server_filesystem_vnic_hostname_prefix = "${var.metadata_server_hostname_prefix}fs-vnic-"
  storage_server_filesystem_vnic_hostname_prefix = "${var.storage_server_hostname_prefix}fs-vnic-"

  # If ad_number is non-negative use it for AD lookup, else use ad_name.
  # Allows for use of ad_number in TF deploys, and ad_name in ORM.
  # Use of max() prevents out of index lookup call.
  ad = "${var.ad_number >= 0 ? lookup(data.oci_identity_availability_domains.availability_domains.availability_domains[max(0,var.ad_number)],"name") : var.ad_name}"

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
/*
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
*/


# Not used for normal terraform apply, added for ORM deployments.
variable "ad_name" {
  default = ""
}


variable "storage_tiering_enabled" {
  default = "false"
  description = "Set to true, if you plan to use multiple storage types (2 or more) to store your hot/warm/cold data. If set to true, you need to set values for atleast 2 storage tiers below.  If set to false, set values for only Storage Tier-1."
}

# Local_NVMe_SSD
variable "storage_tier_1_disk_type" {
  default = "High"
  description = "Use Local_NVMe_SSD value only if DenseIO shape was selected for Storage server. Otherwise select block volume storage types (high, balanced, low) based on your performance needs. Valid values are Local_NVMe_SSD, High, Balanced."
}

variable "storage_tier_2_disk_type" {
  default = "Balanced"
  description = "Select block volume storage types (high, balanced, low) based on your performance needs. Valid values are High, Balanced or Low."
}

variable "storage_tier_3_disk_type" {
  default = "Low"
  description = "Select None or block volume storage types (high, balanced, low) based on your performance needs. Valid values are None, Balanced or Low."
}

variable "storage_tier_4_disk_type" {
  default = "Low"
  description = "Select None or block volume storage types (high, balanced, low) based on your performance needs. Valid values are None or Low."
}

variable "storage_tier_1_disk_count" {
  default = "3"
  description = "Number of local NVMe SSD/block volume disk. Each attached as JBOD (no RAID)."
}

variable "storage_tier_2_disk_count" {
  default = "2"
  description = "Number of block volume/disk. Each attached as JBOD (no RAID)."
}

variable "storage_tier_3_disk_count" {
  default = "1"
  description = "Number of block volume/disk. Each attached as JBOD (no RAID)."
}

variable "storage_tier_4_disk_count" {
  default = "0"
  description = "Number of block volume/disk. Each attached as JBOD (no RAID)."
}


variable "storage_tier_1_disk_size" {
  default = "50"
  description = "If Storage Tier Disk Type is Local_NVMe_SSD, then this field will be ignored.  Otherwise set Size in GB for each block volume/disk, min 50."
}

variable "storage_tier_2_disk_size" {
  default = "50"
  description = "Size in GB for each block volume/disk, min 50."
}

variable "storage_tier_3_disk_size" {
  default = "50"
  description = "Size in GB for each block volume/disk, min 50."
}

variable "storage_tier_4_disk_size" {
  default = "50"
  description = "Size in GB for each block volume/disk, min 50."
}



variable "volume_attach_device_mapping" {
  type = map(string)
  default = {
    "0" = "/dev/oracleoci/oraclevdb"
    "1" = "/dev/oracleoci/oraclevdc"
    "2" = "/dev/oracleoci/oraclevdd"
    "3" = "/dev/oracleoci/oraclevde"
    "4" = "/dev/oracleoci/oraclevdf"
    "5" = "/dev/oracleoci/oraclevdg"
    "6" = "/dev/oracleoci/oraclevdh"
    "7" = "/dev/oracleoci/oraclevdi"
    "8" = "/dev/oracleoci/oraclevdj"
    "9" = "/dev/oracleoci/oraclevdk"
    "10" = "/dev/oracleoci/oraclevdl"
    "11" = "/dev/oracleoci/oraclevdm"
    "12" = "/dev/oracleoci/oraclevdn"
    "13" = "/dev/oracleoci/oraclevdo"
    "14" = "/dev/oracleoci/oraclevdp"
    "15" = "/dev/oracleoci/oraclevdq"
    "16" = "/dev/oracleoci/oraclevdr"
    "17" = "/dev/oracleoci/oraclevds"
    "18" = "/dev/oracleoci/oraclevdt"
    "19" = "/dev/oracleoci/oraclevdu"
    "20" = "/dev/oracleoci/oraclevdv"
    "21" = "/dev/oracleoci/oraclevdw"
    "22" = "/dev/oracleoci/oraclevdx"
    "23" = "/dev/oracleoci/oraclevdy"
    "24" = "/dev/oracleoci/oraclevdz"
    "25" = "/dev/oracleoci/oraclevdaa"
    "26" = "/dev/oracleoci/oraclevdab"
    "27" = "/dev/oracleoci/oraclevdac"
    "28" = "/dev/oracleoci/oraclevdad"
    "29" = "/dev/oracleoci/oraclevdae"
    "30" = "/dev/oracleoci/oraclevdaf"
    "31" = "/dev/oracleoci/oraclevdag"
  }
}

variable "volume_type_vpus_per_gb_mapping" {
  type = map(string)
  default = {
    "High" = "20"
    "Balanced" = "10"
    "Low" = "0"
    "None" = "-1"
  }
}
