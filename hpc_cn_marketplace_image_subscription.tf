#Local variables pointing to the Marketplace catalog resource
#Eg. Modify accordingly to your Application/Listing
locals {
  hpc_cn_mp_listing_id               = var.hpc_cn_mp_listing_id
  hpc_cn_mp_listing_resource_id      = var.hpc_cn_mp_listing_resource_id
  hpc_cn_mp_listing_resource_version = var.hpc_cn_mp_listing_resource_version
}

#Get Image Agreement
resource "oci_core_app_catalog_listing_resource_version_agreement" "hpc_cn_mp_image_agreement" {
  count = var.use_marketplace_image ? 1 : 0

  listing_id               = local.hpc_cn_mp_listing_id
  listing_resource_version = local.hpc_cn_mp_listing_resource_version
}

#Accept Terms and Subscribe to the image, placing the image in a particular compartment
resource "oci_core_app_catalog_subscription" "hpc_cn_mp_image_subscription" {
  count                    = var.use_marketplace_image ? 1 : 0
  compartment_id           = var.compartment_ocid
  eula_link                = oci_core_app_catalog_listing_resource_version_agreement.hpc_cn_mp_image_agreement[0].eula_link
  listing_id               = oci_core_app_catalog_listing_resource_version_agreement.hpc_cn_mp_image_agreement[0].listing_id
  listing_resource_version = oci_core_app_catalog_listing_resource_version_agreement.hpc_cn_mp_image_agreement[0].listing_resource_version
  oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.hpc_cn_mp_image_agreement[0].oracle_terms_of_use_link
  signature                = oci_core_app_catalog_listing_resource_version_agreement.hpc_cn_mp_image_agreement[0].signature
  time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.hpc_cn_mp_image_agreement[0].time_retrieved

  timeouts {
    create = "20m"
  }
}

# Gets the partner image subscription
data "oci_core_app_catalog_subscriptions" "hpc_cn_mp_image_subscription" {
  #Required
  compartment_id = var.compartment_ocid

  #Optional
  listing_id = local.hpc_cn_mp_listing_id

  filter {
    name   = "listing_resource_version"
    values = [local.hpc_cn_mp_listing_resource_version]
  }
}


