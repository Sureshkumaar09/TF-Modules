resource "openstack_lb_loadbalancer_v2" "internal_lb" {
  vip_subnet_id = "${var.subnet_id}"
  name          = "${var.name}-ilb"

  vip_address = var.vip_address
  description = var.lb_description
}

resource "openstack_lb_listener_v2" "listener" {
  count           = "${length(var.lb_config)}"
  name            = "${var.name}_${lookup(element(var.lb_config, count.index), "frontend_port", "")}-listener"
  protocol        = "${lookup(element(var.lb_config, count.index), "protocol", "")}"
  protocol_port   = "${lookup(element(var.lb_config, count.index), "frontend_port", "")}"
  loadbalancer_id = "${openstack_lb_loadbalancer_v2.internal_lb.id}"
  description     = var.listener_description
}

resource "openstack_lb_pool_v2" "pool" {
  count       = "${length(var.lb_config)}"
  name        = "${var.name}_${lookup(element(var.lb_config, count.index), "frontend_port", "")}_${lookup(element(var.lb_config, count.index), "backend_port", "")}-pool"
  protocol    = "${lookup(element(var.lb_config, count.index), "protocol", "")}"
  lb_method   = "${lookup(element(var.lb_config, count.index), "method", "")}"
  listener_id = "${element(openstack_lb_listener_v2.listener.*.id, count.index)}"
  description = var.pool_description

  persistence {
    type        = "${lookup(element(var.lb_config, count.index), "persistence_type", "")}"
    cookie_name = "${lookup(element(var.lb_config, count.index), "cookie_name", "")}"
  }
}

resource "openstack_lb_member_v2" "member" {
  count         = "${length(var.ip_address)}"
  address       = "${element(var.ip_address, floor(count.index % length(var.ip_address)))}"
  protocol_port = "${lookup(element(var.lb_config, floor(count.index / length(var.ip_address))), "backend_port", "")}"
  pool_id       = "${element(openstack_lb_pool_v2.pool.*.id, floor(count.index / length(var.ip_address)))}"
  subnet_id     = "${var.subnet_id}"
}

# DOC: https://www.terraform.io/docs/providers/openstack/r/lb_monitor_v2.html
resource "openstack_lb_monitor_v2" "monitor" {
  count          = length(var.healthcheck)
  pool_id        = lookup(element(openstack_lb_pool_v2.pool, count.index), "id", "")
  name           = lookup(element(var.healthcheck, count.index), "name", "")
  type           = lookup(element(var.healthcheck, count.index), "type", "HTTP")
  delay          = lookup(element(var.healthcheck, count.index), "delay", "60")
  timeout        = lookup(element(var.healthcheck, count.index), "timeout", "5")
  max_retries    = lookup(element(var.healthcheck, count.index), "max_retries", "3")
  url_path       = lookup(element(var.healthcheck, count.index), "url_path", "")
  http_method    = lookup(element(var.healthcheck, count.index), "http_method", "GET")
  expected_codes = lookup(element(var.healthcheck, count.index), "expected_codes", "200")
  admin_state_up = lookup(element(var.healthcheck, count.index), "admin_state_up", "false")
}
