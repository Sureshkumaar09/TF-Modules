data "openstack_networking_secgroup_v2" "default" {
  name = "default"
}

data "openstack_networking_secgroup_v2" "storage" {
  name = "storage"
}

data "openstack_networking_network_v2" "storage" {
  name = "${var.storage_network}"
}

data "openstack_networking_network_v2" "floatingip_network" {
  name = var.floatingip_network
}

data "openstack_networking_subnet_v2" "floatingip_subnet" {
  network_id = data.openstack_networking_network_v2.floatingip_network.id
  name       = var.floatingip_subnet
}
