variable "dc" {}

variable "region" {}

variable "share_proto" {}

variable "availability_zone" {}

variable "nfs_share_sizes" {
  type    = "map"
  default = {}
}

variable "cifs_share_sizes" {
  type    = "map"
  default = {}
}

variable "share_network_id" {}

variable "cifs_subnet" {}

variable "nfs_subnet" {}
