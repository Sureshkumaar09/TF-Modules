output "share_ids" {
  value = "${openstack_sharedfilesystem_share_v2.share.*.id}"
}

output "share_names" {
  value = "${openstack_sharedfilesystem_share_v2.share.*.name}"
}

output "export_locations" {
  value = "${openstack_sharedfilesystem_share_v2.share.*.export_locations}"
}