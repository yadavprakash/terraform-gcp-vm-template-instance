output "id" {
  value       = join("", google_compute_instance_from_template.compute_instance[*].id)
  description = "An identifier for the resource with format"
}
output "template_id" {
  value       = join("", google_compute_instance_template.tpl[*].id)
  description = "An identifier for the resource with format"

}
output "metadata_fingerprint" {
  value       = join("", google_compute_instance_from_template.compute_instance[*].metadata_fingerprint)
  description = "The unique fingerprint of the metadata."
}
output "template_tags_fingerprint" {
  value       = join("", google_compute_instance_template.tpl[*].tags_fingerprint)
  description = " The unique fingerprint of the tags."

}
output "template_metadata_fingerprint" {
  value       = join("", google_compute_instance_template.tpl[*].metadata_fingerprint)
  description = "An identifier for the resource with format"

}
output "self_link" {
  value = join("", google_compute_instance_from_template.compute_instance[*].self_link)

  description = " The URI of the created resource."
}
output "template_self_link" {
  value = join("", google_compute_instance_template.tpl[*].self_link)

  description = "An identifier for the resource with format"

}

output "self_link_unique" {
  value       = join("", google_compute_instance_template.tpl[*].self_link_unique)
  description = " A special URI of the created resource that uniquely identifies this instance template with the following format:"
}
output "instances_self_links" {
  description = "List of self-links for compute instances"
  value       = google_compute_instance_from_template.compute_instance[*].self_link
}

output "instances_details" {
  description = "List of all details for compute instances"
  value       = google_compute_instance_from_template.compute_instance[*]
}

output "available_zones" {
  description = "List of available zones in region"
  value       = data.google_compute_zones.available.names
}