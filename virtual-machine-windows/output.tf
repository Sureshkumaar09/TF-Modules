output "instance_id" {
  value = "${openstack_compute_instance_v2.instance.*.id}"
}

output "instances_ip" {
  value = "${openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4}"
}
