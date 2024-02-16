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
  name          = "dev-firewall"
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
# instance_template module call.
#--------------------------------------------------------------------------------

module "instance_template" {
  source               = "../../"
  name                 = "dev"
  environment          = "test"
  region               = "asia-northeast1"
  source_image         = "ubuntu-2204-jammy-v20230908"
  source_image_family  = "ubuntu-2204-lts"
  source_image_project = "ubuntu-os-cloud"
  disk_size_gb         = "20"
  subnetwork           = module.subnet.subnet_id
  instance_template    = true
  service_account      = null
  ## public IP if enable_public_ip is true
  enable_public_ip = true
  metadata = {
    ssh-keys = <<EOF
      dev:ssh-rsa AAAAB3NzaC1yc2EAA/3mwt2y+PDQMU= ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCx9HrdPJD7zv9SJlAKlssHr2CUSvifRBy+bRp2jRvP851p8RiMshlbrkaRAJV7gh0AFAxL6S7znWzGwFQZFv/XP9fEqD8B7XEOtVIZK+99AYRZfkO62WG5BR6vmN1u3ei2zHSY2IuCmita27BOaimfUCXFdPMUMXwKoTMvThK6UVKaoa+IWR7qkG0b7ByLKZBTsCgBlXH4xLkZsFdCsEDWog4ZJcY5F2tPwZkHoqI0g45CcJMlsfC1KMOkN0MLPAR/iR/wfsQ9Zp0GGFwAn3uJXrcAjUGv1/+giw7RYEnmR3PA5CpzuTNJrnNI2KoFUmh7HSRt5atNg0AEj+043I7B23/yKNBaiqqaNSiv5/qO29n1eSkDhQ7l2sLxAcMS3PkTMKcsf89KkqHDt8AEBWUuCPwVTrsSwAF1Fcfj4Fe4LQUYogM5d+Y3u95LdaaCizM8i/RJ0R6aR//OLtvlHeGJFVjSPiazVJea8ZvR+4nO4b67ic6YZvwfVCEUw+ttbb0= kamal@kamal
    EOF
  }
}
#--------------------------------------------------------------------------------
# compute_instance module call.
#--------------------------------------------------------------------------------
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
  source_instance_template = module.instance_template.self_link_unique
}