variable "name" {}

variable "dc" {}

variable "region" {}

variable "subnet_id" {}

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
variable "win_admin_username" {}
variable "admin_password" {}

variable "image_name" {}

variable "network_id" {}
variable "storage_network" {}
variable "user_data" {}
variable "primary_name_server" {}
variable "secondary_name_server" {}

variable "hdd_disk_size_gb" {
  default = ""
}

variable "hdd_disk_count" {
  default = 0
}

variable "yum_repo_url" {}

variable "chef_server_url" {}

variable "chef_environment" {}

variable "include_platform_install" {}

variable "num_start" {
  default = "0"
}
