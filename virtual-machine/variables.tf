variable "name" {}

variable "dc" {}

variable "region" {}

variable "subnet_id" {}
variable "storage_subnet_id" {
  default = ""
}

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

variable "index_start" {
  default = ""
}

variable "vm_size" {}

variable "admin_username" {}

variable "admin_password" {}

variable "image_name" {}

variable "network_id" {}
variable "storage_network" {}
variable "user_data" {
  default = "init.sh"
}

variable "hdd_disk_size_gb" {
  default = ""
}
variable "hdd_disk_device" {
  default = ""
}


variable "name_extension" {
  default = ""
}

variable "hdd_disk_count" {
  default = 0
}

variable "hdd_disks" {
  type = "map"

  default = {
    "0" = ""
    "1" = ""
  }
}

variable "include_platform_install" {}

variable "floatingip_network" {
  default = "FloatingIP-external-hcm-02"
}
variable "floatingip" {}
variable "floatingip_subnet" {
  default = "FloatingIP-sap-hcm-01"
}
