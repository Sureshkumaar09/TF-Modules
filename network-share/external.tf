data "openstack_networking_subnet_v2" "nfs" {
  name = "${var.nfs_subnet}"
}

data "openstack_networking_subnet_v2" "cifs" {
  name = "${var.cifs_subnet}"
}
