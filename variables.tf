###
## Variables.tf for Terraform
## Defines variables and local values
###




# 172.28.0.0/16   10.0.0.0/16
variable vpc_cidr { default = "10.0.0.0/16" }

variable beegfs_high_availability { default = false }
variable management_high_availability { default = false }
variable metadata_high_availability { default = false }
variable storage_high_availability { default = false }

# set to true if you want to use OCI Block Volume with Multi-attach feature (SAN like storage) instead of BeeGFS Buddy Mirror/replication feature for HA solution.
variable metadata_use_shared_disk { default = false }
# set to true if you want to use OCI Block Volume with Multi-attach feature (SAN like storage) instead of BeeGFS Buddy Mirror/replication feature for HA solution.
variable storage_use_shared_disk { default = false }


# Has to be within the subnet "fs" CIDR range. Better to use an IP which is closer to the end of the CIDR range.
variable management_vip_private_ip { default = "10.0.2.254" }

# we need to define a VIP for each pair of metadata servers.
# Has to be within the subnet "fs" CIDR range. Better to use an IP which is closer to the end of the CIDR range.
variable "metadata_vip_private_ip" {
  default = "10.0.2.253,10.0.2.252"
}

# we need to define a VIP for each pair of storage servers.
variable "storage_vip_private_ip" {  
  default = "10.0.2.251,10.0.2.250"
}

variable "ha_vip_mapping" {
  type = map(string)
  default = {
    "1"  = "10.0.2.254"
    "2"  = "10.0.2.253"
    "3"  = "10.0.2.252"
    "4"  = "10.0.2.251"
    "5"  = "10.0.2.250"
    "6"  = "10.0.2.249"
    "7"  = "10.0.2.248"
    "8"  = "10.0.2.247"
    "9"  = "10.0.2.246"
    "10"  = "10.0.2.245"
    "11"  = "10.0.2.244"
    "12"  = "10.0.2.243"
    "13"  = "10.0.2.242"
    "14"  = "10.0.2.241"
    "15"  = "10.0.2.240"
    "16"  = "10.0.2.239"
  }
}

variable bastion_shape { default = "VM.Standard2.2" }
# Number of OCPU's for flex shape
variable bastion_ocpus { default = "1" }
variable bastion_node_count { default = 1 }
variable bastion_hostname_prefix { default = "bastion-" }

# BeeGFS Management (MGS) Server nodes variables
variable management_server_shape { default = "VM.Standard2.2" }
# Number of OCPU's for flex shape
variable management_server_ocpus { default = "1" }
variable management_server_node_count { default = 2 }
variable management_server_disk_count { default = 1 }
variable management_server_disk_size { default = 50 }
# Block volume elastic performance tier.  The number of volume performance units (VPUs) that will be applied to this volume per GB, representing the Block Volume service's elastic performance options. See https://docs.cloud.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm for more information.  Allowed values are High, Balanced, and Low.  Recommended value is Balanced for balanced performance and High to receive higher performance (IO throughput and IOPS) per GB.
variable management_server_disk_vpus_per_gb { default = "Balanced" }
variable management_server_hostname_prefix { default = "mgs-server-" }


# BeeGFS Metadata (MDS) Server nodes variables  #VM.Standard2.8
variable metadata_server_shape { default = "VM.Standard2.24" }
# Number of OCPU's for flex shape
variable metadata_server_ocpus { default = "1" }
variable metadata_server_node_count { default = 2 }
# if disk_count > 1, then it create multiple MDS instance, each with 1 disk as MDT for optimal performance. If node has both local nvme ssd and block storage, block storage volumes will be ignored.
variable metadata_server_disk_count { default = 1 }
# 500
variable metadata_server_disk_size { default = 400 }
# Block volume elastic performance tier.  The number of volume performance units (VPUs) that will be applied to this volume per GB, representing the Block Volume service's elastic performance options. See https://docs.cloud.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm for more information.  Allowed values are High, Balanced, and Low.  Recommended value is Balanced for balanced performance and High to receive higher performance (IO throughput and IOPS) per GB.
variable metadata_server_disk_vpus_per_gb { default = "High" }
variable metadata_server_hostname_prefix { default = "metadata-server-" }


# BeeGFS Stoarage/Object (OSS) Server nodes variables BM.Standard2.52
variable storage_server_shape { default = "BM.Standard2.52" }
# Number of OCPU's for flex shape
variable storage_server_ocpus { default = "1" }
variable storage_server_node_count { default = 2 }
variable storage_server_hostname_prefix { default = "storage-server-" }


# Client nodes variables VM.Standard2.24, VM.Standard2.2 , BM.HPC2.36
variable client_node_shape { default = "BM.HPC2.36" }
# Number of OCPU's for flex shape
variable client_node_ocpus { default = "1" }
variable client_node_count { default = 0 }
variable client_node_hostname_prefix { default = "client-" }



# BeeGFS FS related variables
# Default file stripe size (aka chunk_size) used by clients to striping file data and send to desired number of storage targets (OSTs). Example: 1m, 512k, 2m, etc
variable beegfs_stripe_size { default = "1m" }
variable beegfs_mount_point { default = "/mnt/beegfs" }

# This is currently used for the deployment.  
variable "ad_number" {
  default = "-1"
}


variable "storage_tier_1_disk_type" {
  default = "Balanced"
  description = "Use Local_NVMe_SSD value only if DenseIO shape was selected for Storage server. Otherwise select block volume storage types (high, balanced, low) based on your performance needs. Valid values are Local_NVMe_SSD, High, Balanced, Low."
}

variable "storage_tier_2_disk_type" {
  default = "Balanced"
  description = "Select block volume storage types (high, balanced, low) based on your performance needs. Valid values are None, High, Balanced or Low."
}

variable "storage_tier_3_disk_type" {
  default = "Low"
  description = "Select None or block volume storage types (high, balanced, low) based on your performance needs. Valid values are None, Balanced or Low."
}

variable "storage_tier_4_disk_type" {
  default = "Low"
  description = "Select None or block volume storage types (high, balanced, low) based on your performance needs. Valid values are None or Low."
}

# 8
variable "storage_tier_1_disk_count" {
  default = "20"
  description = "Number of local NVMe SSD/block volume disk. Each attached as JBOD (no RAID)."
}

variable "storage_tier_2_disk_count" {
  default = "0"
  description = "Number of block volume/disk. Each attached as JBOD (no RAID)."
}

variable "storage_tier_3_disk_count" {
  default = "0"
  description = "Number of block volume/disk. Each attached as JBOD (no RAID)."
}

variable "storage_tier_4_disk_count" {
  default = "0"
  description = "Number of block volume/disk. Each attached as JBOD (no RAID)."
}

# 800
variable "storage_tier_1_disk_size" {
  default = "5000"
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
  # hard coding the default to 1, instead of using var.management_server_node_count, incase user sets it to 2, then logic will fail.
  derived_management_server_node_count = var.management_high_availability ? 2 : 1
  #derived_metadata_server_node_count  = var.metadata_high_availability ? 2 : 1
  derived_metadata_server_node_count   = var.metadata_high_availability ? ((var.metadata_server_node_count > 1 && var.metadata_server_node_count % 2 == 0) ? var.metadata_server_node_count : "Should be multiplier of 2 for high availabilty" ) : var.metadata_server_node_count
  derived_storage_server_node_count   = var.storage_high_availability ? ((var.storage_server_node_count > 1 && var.storage_server_node_count % 2 == 0) ? var.storage_server_node_count : "Should be multiplier of 2 for high availabilty" ) : var.storage_server_node_count

  management_server_dual_nics  = (length(regexall("^BM", var.management_server_shape)) > 0 ? true : false)
  management_server_hpc_shape  = (length(regexall("HPC2", var.management_server_shape)) > 0 ? true : false)
  metadata_server_dual_nics    = (length(regexall("^BM", var.metadata_server_shape)) > 0 ? true : false)
  metadata_server_hpc_shape    = (length(regexall("HPC2", var.metadata_server_shape)) > 0 ? true : false)
  storage_server_dual_nics     = (length(regexall("^BM", var.storage_server_shape)) > 0 ? true : false)
  storage_server_hpc_shape     = (length(regexall("HPC2", var.storage_server_shape)) > 0 ? true : false)
  client_hpc_shape             = (length(regexall("HPC2", var.client_node_shape)) > 0 ? true : false)
  storage_subnet_domain_name   = ("${data.oci_core_subnet.storage_subnet.dns_label}.${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com" )
  filesystem_subnet_domain_name= ( "${data.oci_core_subnet.fs_subnet.dns_label}.${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com" )
  vcn_domain_name              = ("${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com" )

  management_server_filesystem_vnic_hostname_prefix = "${var.management_server_hostname_prefix}fs-vnic-"
  metadata_server_filesystem_vnic_hostname_prefix   = "${var.metadata_server_hostname_prefix}fs-vnic-"
  storage_server_filesystem_vnic_hostname_prefix    = "${var.storage_server_hostname_prefix}fs-vnic-"

  is_bastion_flex_shape = var.bastion_shape == "VM.Standard.E3.Flex" ? [var.bastion_ocpus]:[]
  is_management_server_flex_shape = var.management_server_shape == "VM.Standard.E3.Flex" ? [var.management_server_ocpus]:[]
  is_metadata_server_flex_shape = var.metadata_server_shape == "VM.Standard.E3.Flex" ? [var.metadata_server_ocpus]:[]
  is_storage_server_flex_shape = var.storage_server_shape == "VM.Standard.E3.Flex" ? [var.storage_server_ocpus]:[]
  is_client_node_flex_shape = var.client_node_shape == "VM.Standard.E3.Flex" ? [var.bastion_ocpus]:[]


  # If ad_number is non-negative use it for AD lookup, else use ad_name.
  # Allows for use of ad_number in TF deploys, and ad_name in ORM.
  # Use of max() prevents out of index lookup call.
  ad = var.ad_number >= 0 ? lookup(data.oci_identity_availability_domains.availability_domains.availability_domains[max(0,var.ad_number)],"name") : var.ad_name
}

/*
variable "imagesCentos" {
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
*/

// See https://docs.cloud.oracle.com/en-us/iaas/images/image/0a72692a-bdbb-46fc-b17b-6e0a3fedeb23/
// Oracle-provided image "Oracle-Linux-7.7-2020.01.28-0"
// Kernel Version: 4.14.35-1902.10.4.el7uek.x86_64
variable "images" {
  type = map(string)
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



# Not used for normal terraform apply, added for ORM deployments.
variable "ad_name" {
  default = ""
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
    "High"     = 20
    "Balanced" = 10
    "Low"      = 0
    "None"     = -1
  }
}


# Generate a new strong password for hacluster user
resource "random_string" "hacluster_user_password" {
  length      = 16
  special     = true
  min_special = 2
  upper       = true
  min_upper   = 2
  lower       = true
  min_lower   = 2 
  number      = true
  min_numeric = 2
  override_special = "!@#-_&*=+"
}

output "hacluster_user_password" {
  value = [random_string.hacluster_user_password.result]
}

/*
Range of VIP IPs to use for up 20 OSS servers in a cluster.
Only required if storage_use_shared_disk=true for HA
For HA with Beegfs Buddy Mirror - this is not used. 

variable "oss_vip_private_ip" {
  type = map(string)
  default = {
    "0"      = "10.0.2.252"
    "2"      = "10.0.2.251"
    "4"      = "10.0.2.250"
    "6"      = "10.0.2.249"
    "8"      = "10.0.2.248"
    "10"     = "10.0.2.247"
    "12"     = "10.0.2.246"
    "14"     = "10.0.2.245"
    "16"     = "10.0.2.244"
    "18"     = "10.0.2.243"
  }
}
*/

#-------------------------------------------------------------------------------------------------------------
# Marketplace variables
# hpc-filesystem-BeeGFS-OL77_4.14.35-1902.10.4.el7uek.x86_64
# Oracle Linux 7.7 UEK Image for BeeGFS filesystem on Oracle Cloud Infrastructure
# ------------------------------------------------------------------------------------------------------------

variable "mp_listing_id" {
  default = "ocid1.appcataloglisting.oc1..aaaaaaaadu427jmx3pbdw76ek6xkgin4ucmfbrlsavb45snvzk5d7ckrs3nq"
}
variable "mp_listing_resource_id" {
  default = "ocid1.image.oc1..aaaaaaaa6pvs3ovuveqb7pepzjhemyykkyjae7tttrb2fkf5adzwqm3izvxq"
}
variable "mp_listing_resource_version" {
 default = "1.0"
}
variable "use_marketplace_image" {
  default = true
}

#-------------------------------------------------------------------------------------------------------------
# Marketplace variables
# hpc-filesystem-BeeGFS-OL77_3.10.0-1062.9.1.el7.x86_64
# ------------------------------------------------------------------------------------------------------------
/*
variable "mp_listing_id" {
  default = "ocid1.appcataloglisting.oc1..aaaaaaaajmdokvtzailtlchqxk7nai45fxar6em7dfbdibxmspjsvs4uz3uq"
}
variable "mp_listing_resource_id" {
  default = "ocid1.image.oc1..aaaaaaaacnodhlnuidkvnlvu3dpu4n26knkqudjxzfpq3vexi7cobbclmbxa"
}
variable "mp_listing_resource_version" {
 default = "1.0"
}
variable "use_marketplace_image" {
  default = true
}
*/

# ------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------
# Marketplace variables for Management Server High Availability setup
# Artifact - High_Availability_DRBD_Pacemaker_Corosync_OL77_3.10.0-1062.9.1.el7
# ------------------------------------------------------------------------------------------------------------
/*
variable "mp_listing_id" {
default = "ocid1.appcataloglisting.oc1..aaaaaaaayhsvdenfgrpw6jich4o6t2gtgfrudyfgih5i7z2dmjfqowalmerq"
}
variable "mp_listing_resource_id" {
default = "ocid1.image.oc1..aaaaaaaanvvgvh3237ggcsxpzbielgrixuepfbylohfn6752nohhlzgmkzsa"
}
variable "mp_listing_resource_version" {
default = "1.0_03052020"
}
variable "use_marketplace_image" {
default = true
}
*/
# ------------------------------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------------
# Marketplace variables for HPC Client/Compute Node
# Artifact - HPC CN Image - https://github.com/oci-hpc/oci-hpc-clusternetwork/blob/6c72b18736f076b169bf14780add58387156bc77/util.tf
# ------------------------------------------------------------------------------------------------------------

variable "hpc_cn_mp_listing_id" {
default = "ocid1.appcataloglisting.oc1..aaaaaaaahz2xiwfcsbebmqg7sp6lhdt6r2vsjro5jfukkl5cntlqvfhkbzaq"
}
variable "hpc_cn_mp_listing_resource_id" {
default = "ocid1.image.oc1..aaaaaaaafgzcla4pkskkegec3okzhbtmaylnldbxoa4ln7d6npytnqwu3mca"
}
variable "hpc_cn_mp_listing_resource_version" {
default = "20190906"
}

# ------------------------------------------------------------------------------------------------------------




variable "use_existing_vcn" {
  default = "false"
}

variable "vcn_id" {
  default = "ocid1.vcn.oc1.ap-osaka-1.amaaaaaa7rhxvoaaexoygwttphgshtv4li6aoseag7jq7f5qpr5tvyrzfpha"
}

variable "bastion_subnet_id" {
  default = "ocid1.subnet.oc1.ap-osaka-1.aaaaaaaazfhespkc4oorh55cluresxbqica4hxv2u7tmwnnuc35pfkarhuca"
}

variable "storage_subnet_id" {
  default = "ocid1.subnet.oc1.ap-osaka-1.aaaaaaaa7b3yeiy6cfalnfsvil4ln27eow7v3qzczw2kvs3q4scetehaukya"
}

variable "fs_subnet_id" {
  default = "ocid1.subnet.oc1.ap-osaka-1.aaaaaaaae42bf6ihqlhvtb3pamdgvy6yno4vcqlqbus3pb3wxrai4k4yyzfa"
}



