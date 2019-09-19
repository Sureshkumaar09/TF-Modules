

data "openstack_networking_secgroup_v2" "storage" {
  name = "${var.storage_security_group}"
}


data "openstack_networking_network_v2" "private" {
  name = "${var.private_network}"
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

# need to use external data due to the way baremetal work in openstack
# https://documentation.global.cloud.sap/docs/servers/baremetal_config.html
data "external" "get_working_interface" {
  count = "${var.num}"
  program = ["ruby", "${path.module}/get_working_interface.rb"]

  query = {
    network = "${jsonencode(openstack_compute_instance_v2.instance[count.index].network)}"
  }
}

# need to use external data due to the way baremetal work in openstack
# https://documentation.global.cloud.sap/docs/servers/baremetal_config.html
data "external" "get_local_link_information" {
  count = "${var.num}"
  program = ["ruby", "${path.module}/get_local_link_information.rb"]

  query = {
    bm_ports = "${jsonencode(data.openstack_networking_port_v2.bm_ports)}"
    host_id = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
  }
}