
locals {
  share_name_list           = "${compact(split(",", var.share_name_list))}"
  share_size_list           = "${compact(split(",", var.share_size_gb_list))}"
}


data "openstack_sharedfilesystem_sharenetwork_v2" "share_network" {
  name = "${var.share_network_name}"
}

resource "openstack_sharedfilesystem_share_v2" "share" {
  count            = "${length(local.share_size_list)}"
  name             = "${local.share_name_list[count.index]}"
  share_proto      = "${var.share_protocol}"
  size             = "${local.share_size_list[count.index]}"
  share_network_id = "${data.openstack_sharedfilesystem_sharenetwork_v2.share_network.id}"
  availability_zone = "${element(var.availability_zone, count.index % length(var.availability_zone))}"
}

resource "openstack_sharedfilesystem_share_access_v2" "share_access" {
  count            = "${var.set_share_access == "" || var.set_share_access == "false" ? 0: length(local.share_size_list)}"
  share_id     = "${openstack_sharedfilesystem_share_v2.share[count.index].id}"
  access_type  = "ip"
  access_to    = "${data.openstack_sharedfilesystem_sharenetwork_v2.share_network.cidr}"
  access_level = "${var.share_access_level}"
}