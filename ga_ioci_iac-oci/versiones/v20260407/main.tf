module "oci_lz_orchestrator" {
  source = "../terraform-oci-modules-orchestrator"

  tenancy_ocid         = var.tenancy_ocid
  user_ocid            = var.user_ocid
  fingerprint          = var.fingerprint
  private_key_path     = var.private_key_path
  private_key_password = var.private_key_password
  region               = var.region

  compartments_configuration   = var.compartments_configuration
  groups_configuration         = var.groups_configuration
  dynamic_groups_configuration = var.dynamic_groups_configuration
  policies_configuration       = var.policies_configuration

  identity_domains_configuration                   = var.identity_domains_configuration
  identity_domain_groups_configuration             = var.identity_domain_groups_configuration
  identity_domain_dynamic_groups_configuration     = var.identity_domain_dynamic_groups_configuration
  identity_domain_identity_providers_configuration = var.identity_domain_identity_providers_configuration
  identity_domain_applications_configuration       = var.identity_domain_applications_configuration

  network_configuration            = var.network_configuration
  nlb_configuration                = var.nlb_configuration
  streams_configuration            = var.streams_configuration
  notifications_configuration      = var.notifications_configuration
  events_configuration             = var.events_configuration
  home_region_events_configuration = var.home_region_events_configuration

  alarms_configuration             = var.alarms_configuration
  service_connectors_configuration = var.service_connectors_configuration
  logging_configuration            = var.logging_configuration
  scanning_configuration           = var.scanning_configuration
  cloud_guard_configuration        = var.cloud_guard_configuration
  security_zones_configuration     = var.security_zones_configuration
  vaults_configuration             = var.vaults_configuration
  zpr_configuration                = var.zpr_configuration
  bastions_configuration           = var.bastions_configuration
  budgets_configuration            = var.budgets_configuration
  tags_configuration               = var.tags_configuration

  instances_configuration      = var.instances_configuration
  oke_clusters_configuration   = var.oke_clusters_configuration
  oke_workers_configuration    = var.oke_workers_configuration
  object_storage_configuration = var.object_storage_configuration

  compartments_dependency = var.compartments_dependency
  tags_dependency         = var.tags_dependency
  network_dependency      = var.network_dependency
  kms_dependency          = var.kms_dependency
  logging_dependency      = var.logging_dependency
  streams_dependency      = var.streams_dependency
  topics_dependency       = var.topics_dependency
  functions_dependency    = var.functions_dependency
  vaults_dependency       = var.vaults_dependency
  instances_dependency    = var.instances_dependency
  nlbs_dependency         = var.nlbs_dependency

  output_path = var.output_path
}