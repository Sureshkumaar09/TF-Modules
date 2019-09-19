variable "name" {
  default = ""
}

variable "subnet_id" {}

variable "ip_address" {
  default = []
}

variable "lb_config" {
  default = []
}

variable "vip_address" {}

variable "healthcheck" {
  default = []
}

variable "lb_description" {}
variable "pool_description" {}
variable "listener_description" {}
