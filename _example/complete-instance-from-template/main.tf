provider "google" {
  project = "testing-gcp-ops"
  region  = "asia-northeast1"
  zone    = "asia-northeast1-a"
}
#--------------------------------------------------------------------------------
# vpc module call.
#--------------------------------------------------------------------------------
module "vpc" {
  source                                    = "git::git@github.com:opsstation/terraform-gcp-vpc.git?ref=v1.0.0"
  name                                      = "dev"
  environment                               = "test"
  label_order                               = ["name", "environment"]
  mtu                                       = 1460
  routing_mode                              = "REGIONAL"
  google_compute_network_enabled            = true
  network_firewall_policy_enforcement_order = "AFTER_CLASSIC_FIREWALL"
  delete_default_routes_on_create           = false
}

#--------------------------------------------------------------------------------
# subnet module call.
#--------------------------------------------------------------------------------
module "subnet" {
  source        = "git::git@github.com:opsstation/terraform-gcp-subnet.git?ref=v1.0.0"
  subnet_names  = ["dev-subnet1"]
  name          = "dev"
  environment   = "test"
  label_order   = ["name", "environment"]
  gcp_region    = "asia-northeast1"
  network       = module.vpc.vpc_id
  ip_cidr_range = ["10.10.0.0/16"]
}

#--------------------------------------------------------------------------------
# firewall module call.
#--------------------------------------------------------------------------------
module "firewall" {
  source        = "git::git@github.com:opsstation/terraform-gcp-firewall.git?ref=v1.0.0"
  name          = "firewall"
  environment   = "test"
  label_order   = ["name", "environment"]
  network       = module.vpc.vpc_id
  source_ranges = ["0.0.0.0/0"]

  allow = [
    { protocol = "tcp"
      ports    = ["22", "80"]
    }
  ]
}

#--------------------------------------------------------------------------------
# compute_instance module call.
#--------------------------------------------------------------------------------
data "google_compute_instance_template" "generic" {
  name = "instance-temp-dev"
}

module "compute_instance" {
  source                 = "../../"
  name                   = "dev"
  environment            = "instance"
  region                 = "asia-northeast1"
  zone                   = "asia-northeast1-a"
  subnetwork             = module.subnet.subnet_id
  instance_from_template = true
  deletion_protection    = false
  service_account        = null
  ## public IP if enable_public_ip is true
  enable_public_ip         = true
  source_instance_template = data.google_compute_instance_template.generic.self_link
}