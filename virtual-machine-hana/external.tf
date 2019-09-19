#data "openstack_networking_secgroup_v2" "mgmt" {
#  name = "mgmt"
#}

data "openstack_networking_secgroup_v2" "storage" {
  name = "${var.storage_security_group}"
}


data "openstack_networking_network_v2" "storage" {
  name = "${var.storage_network}"
}

data "openstack_networking_network_v2" "backup" {
  name = "${var.backup_network}"
}
data "openstack_networking_network_v2" "heartbeat" {
  name = "${var.heartbeat_network}"
}
data "openstack_networking_subnet_v2" "floatingip" {
  name = "${var.floatingip_subnet}"
}

