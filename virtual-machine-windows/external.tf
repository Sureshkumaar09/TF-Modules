data "openstack_networking_secgroup_v2" "default" {
  name = "default"
}

data "openstack_networking_network_v2" "storage" {
  name = "${var.storage_network}"
}
