module "labels" {
  source      = "git::git@github.com:opsstation/terraform-gcp-labels.git?ref=v1.0.0"
  name        = var.name
  environment = var.environment
  label_order = var.label_order
  managedby   = var.managedby
  repository  = var.repository
}
data "google_client_config" "current" {
}
###########################################
locals {
  source_image         = var.source_image != "" ? var.source_image : "ubuntu-2204-jammy-v20230908"
  source_image_family  = var.source_image_family != "" ? var.source_image_family : "ubuntu-2204-lts"
  source_image_project = var.source_image_project != "" ? var.source_image_project : "ubuntu-os-cloud"

  boot_disk = [
    {
      source_image = var.source_image != "" ? format("${local.source_image_project}/${local.source_image}") : format("${local.source_image_project}/${local.source_image_family}")
      disk_size_gb = var.disk_size_gb
      disk_type    = var.disk_type
      disk_labels  = var.disk_labels
      auto_delete  = var.auto_delete
      boot         = "true"
    },
  ]

  all_disks              = concat(local.boot_disk, var.additional_disks)
  shielded_vm_configs    = var.enable_shielded_vm ? [true] : []
  gpu_enabled            = var.gpu != null
  alias_ip_range_enabled = var.alias_ip_range != null
  on_host_maintenance = (
    var.preemptible || var.enable_confidential_vm || local.gpu_enabled
    ? "TERMINATE"
    : var.on_host_maintenance
  )
  automatic_restart = (
    # must be false when preemptible is true
    var.preemptible ? false : var.automatic_restart
  )
}

#####==============================================================================
##### Manages a VM instance template resource within GCE.
#####==============================================================================
resource "google_compute_instance_template" "tpl" {
  count                   = var.instance_template ? 1 : 0
  name_prefix             = format("%s-%s", module.labels.id, (count.index))
  project                 = data.google_client_config.current.project
  machine_type            = var.machine_type
  labels                  = var.labels
  metadata                = var.metadata
  tags                    = var.tags
  can_ip_forward          = var.can_ip_forward
  metadata_startup_script = var.startup_script
  region                  = var.region
  min_cpu_platform        = var.min_cpu_platform
  dynamic "disk" {
    for_each = local.all_disks
    content {
      auto_delete  = lookup(disk.value, "auto_delete", null)
      boot         = lookup(disk.value, "boot", null)
      device_name  = lookup(disk.value, "device_name", null)
      disk_name    = lookup(disk.value, "disk_name", null)
      disk_size_gb = lookup(disk.value, "disk_size_gb", lookup(disk.value, "disk_type", null) == "local-ssd" ? "375" : null)
      disk_type    = lookup(disk.value, "disk_type", null)
      interface    = lookup(disk.value, "interface", lookup(disk.value, "disk_type", null) == "local-ssd" ? "NVME" : null)
      mode         = lookup(disk.value, "mode", null)
      source       = lookup(disk.value, "source", null)
      source_image = lookup(disk.value, "source_image", null)
      type         = lookup(disk.value, "disk_type", null) == "local-ssd" ? "SCRATCH" : "PERSISTENT"
      labels       = lookup(disk.value, "disk_labels", null)

      dynamic "disk_encryption_key" {
        for_each = compact([var.disk_encryption_key == null ? null : 1])
        content {
          kms_key_self_link = var.disk_encryption_key
        }
      }
    }
  }

  dynamic "service_account" {
    for_each = var.service_account == null ? [] : [var.service_account]
    content {
      email  = lookup(service_account.value, "email", null)
      scopes = lookup(service_account.value, "scopes", null)
    }
  }

  network_interface {
    network            = var.network
    subnetwork         = var.subnetwork
    subnetwork_project = var.subnetwork_project
    network_ip         = length(var.network_ip) > 0 ? var.network_ip : null
    stack_type         = var.stack_type
    dynamic "access_config" {
      for_each = var.enable_public_ip ? [1] : []
      content {
        # Add access_config settings here if needed
      }
    }
    dynamic "ipv6_access_config" {
      for_each = var.ipv6_access_config
      content {
        network_tier = ipv6_access_config.value.network_tier
      }
    }
    dynamic "alias_ip_range" {
      for_each = local.alias_ip_range_enabled ? [var.alias_ip_range] : []
      content {
        ip_cidr_range         = alias_ip_range.value.ip_cidr_range
        subnetwork_range_name = alias_ip_range.value.subnetwork_range_name
      }
    }
  }

  dynamic "network_interface" {
    for_each = var.additional_networks
    content {
      network            = network_interface.value.network
      subnetwork         = network_interface.value.subnetwork
      subnetwork_project = network_interface.value.subnetwork_project
      network_ip         = length(network_interface.value.network_ip) > 0 ? network_interface.value.network_ip : null
      dynamic "access_config" {
        for_each = var.enable_public_ip ? [1] : []
        content {
          # Add access_config settings here if needed
        }
      }
      dynamic "ipv6_access_config" {
        for_each = network_interface.value.ipv6_access_config
        content {
          network_tier = ipv6_access_config.value.network_tier
        }
      }
    }
  }

  lifecycle {
    create_before_destroy = "true"
  }

  scheduling {
    preemptible         = var.preemptible
    automatic_restart   = local.automatic_restart
    on_host_maintenance = local.on_host_maintenance
  }

  advanced_machine_features {
    enable_nested_virtualization = var.enable_nested_virtualization
    threads_per_core             = var.threads_per_core
  }

  dynamic "shielded_instance_config" {
    for_each = local.shielded_vm_configs
    content {
      enable_secure_boot          = lookup(var.shielded_instance_config, "enable_secure_boot", shielded_instance_config.value)
      enable_vtpm                 = lookup(var.shielded_instance_config, "enable_vtpm", shielded_instance_config.value)
      enable_integrity_monitoring = lookup(var.shielded_instance_config, "enable_integrity_monitoring", shielded_instance_config.value)
    }
  }

  confidential_instance_config {
    enable_confidential_compute = var.enable_confidential_vm
  }

  dynamic "guest_accelerator" {
    for_each = local.gpu_enabled ? [var.gpu] : []
    content {
      type  = guest_accelerator.value.type
      count = guest_accelerator.value.count
    }
  }
}
locals {
  static_ips        = concat(var.static_ips, ["NOT_AN_IP"])
  network_interface = length(format("%s%s", var.network, var.subnetwork)) == 0 ? [] : [1]
}

data "google_compute_zones" "available" {
  project = data.google_client_config.current.project
  region  = var.region
}

#####==============================================================================
##### Manages a VM instance resource within GCE.
#####==============================================================================
resource "google_compute_instance_from_template" "compute_instance" {
  provider            = google
  count               = var.instance_from_template ? 1 : 0
  name                = format("%s-%s", module.labels.id, (count.index))
  project             = data.google_client_config.current.project
  zone                = var.zone == null ? data.google_compute_zones.available.names[count.index % length(data.google_compute_zones.available.names)] : var.zone
  deletion_protection = var.deletion_protection
  resource_policies   = var.resource_policies

  dynamic "network_interface" {
    for_each = local.network_interface

    content {
      network            = var.network
      subnetwork         = var.subnetwork
      subnetwork_project = var.subnetwork_project
      network_ip         = length(var.static_ips) == 0 ? "" : element(local.static_ips, count.index)

      dynamic "access_config" {
        for_each = var.enable_public_ip ? [1] : []
        content {
          # Add access_config settings here if needed
        }
      }
      dynamic "ipv6_access_config" {
        for_each = var.ipv6_access_config
        content {
          network_tier = ipv6_access_config.value.network_tier
        }
      }

      dynamic "alias_ip_range" {
        for_each = var.alias_ip_ranges
        content {
          ip_cidr_range         = alias_ip_range.value.ip_cidr_range
          subnetwork_range_name = alias_ip_range.value.subnetwork_range_name
        }
      }
    }
  }
  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }
  source_instance_template = var.source_instance_template
}