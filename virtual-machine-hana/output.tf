output "instance_id" {
  value = "${openstack_compute_instance_v2.instance.*.id}"
}

output "instances_ip" {
  value = "${openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4}"
}

output "instances_name" {
  value = "${openstack_compute_instance_v2.instance.*.name}"
}

output "storage_ips" {
  value = "${openstack_networking_port_v2.nfs_port.*.all_fixed_ips}"
}