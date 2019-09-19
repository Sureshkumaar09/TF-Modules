variable "name" {}

variable "dc" {}

variable "region" {}

#variable "subnet_id" {}

variable "availability_zone" {
  type    = "list"
  default = []
}

variable "security_group_ids" {
  type    = "list"
  default = []
}

variable "bootstrap_config" {
  default = {}
}

#variable "chef_tags" {
#  default = {}
#}

#variable "pool" {
#  default = ""
#}

variable "name_servers" {
  default = {}
}

variable "automation_shares" {
  default = {}
}

variable "public_key" {
  default = {}
}

variable "num" {
  default = 1
}

variable "floatingip" {}

variable "vm_size" {}

variable "admin_username" {}

variable "admin_password" {}

variable "image_name" {}

variable "network_id" {}
variable "storage_network" {}

variable "hdd_disk_size_gb" {
  default = ""
}

variable "name_extension" {
  default = ""
}

variable "include_platform_install" {}

variable "floatingip_network" {
  default = "FloatingIP-external-hcm"
}

variable "floatingip_subnet" {
  default = "FloatingIP-sap-hcm-01"
}

variable "backup_network" {}
variable "heartbeat_network" {}
variable "storage_security_group_ids" {
type    = "list"
  default = []
}
variable "backup_security_group_ids" {
type    = "list"
  default = []
}
variable "heartbeat_security_group_ids" {
type    = "list"
  default = []
}
variable "backup_interface" {
  default = 1
}
variable "heartbeat_interface" {
  default = 1
}
variable "hostname_starting_num" {
  default = 1
}
variable "storage_security_group" {
  default = "storage"
}

variable "platform_cookbook_role" {
  default = "role[hcm_db_hana_os_setup]"
}

variable "update_system" {
  default = "true"
}

variable "shared_filesystem_export_locations" {
  type    = "list"
  default = []
}

variable "shared_filesystem_mount_list" {
  default = ""
}

variable "shared_filesystem_id_list" {
  type    = "list"
  default = []
}

variable "nfs_mount_list" {
  default = ""
}

variable "nfs_export_locations" {
  default = ""
}

variable "nfs_mount_option" {
  default = "nfs rw,vers=4,hard,intr,timeo=600,lock,rsize=1048576,wsize=1048576,actimeo=0,noatime 0 0"
}

variable "node_specific_shared_filesystem_export_locations" {
  type    = "list"
  default = []
}

variable "node_specific_shared_filesystem_mount_list" {
  default = ""
}

variable "node_specific_shared_filesystem_id_list" {
  type    = "list"
  default = []
}

variable "share_access_level" {
    default = "rw"
} 