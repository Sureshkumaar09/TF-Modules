#resource "openstack_sharedfilesystem_sharenetwork_v2" "share_network" {
#  name              = "test_sharenetwork"
#  neutron_net_id    = data.openstack_networking_network_v2.storage.id
#  neutron_subnet_id = data.openstack_networking_subnet_v2.nfs.id
#}

resource "openstack_sharedfilesystem_share_v2" "nfs" {
  for_each         = var.nfs_share_sizes
  name             = each.key
  share_proto      = "NFS"
  size             = each.value.size
  description      = each.value.desc
  share_network_id = var.share_network_id
  availability_zone = var.availability_zone
}

resource "openstack_sharedfilesystem_share_access_v2" "nfs_access" {
  count        = length(keys(openstack_sharedfilesystem_share_v2.nfs))
  share_id     = openstack_sharedfilesystem_share_v2.nfs[keys(openstack_sharedfilesystem_share_v2.nfs)[count.index]].id
  access_type  = "ip"
  access_to    = data.openstack_networking_subnet_v2.nfs.cidr
  access_level = "rw"
}
