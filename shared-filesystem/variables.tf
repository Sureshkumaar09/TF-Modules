variable "share_protocol" {}

variable "share_network_name" {}

variable "share_name_list" {}

variable "share_size_gb_list" {}


variable "share_access_level" {
    default = "rw"
} 

variable "availability_zone" {
  type    = "list"
  default = []
}

variable "set_share_access" {
  default=""
}