

# LB monitor section
An openstack monitor object for loadbalancer healthchecks. 
* _openstack\_lb\_monitor\_v2_
* _load\_balancer\_probe_

```
module "app-internal-loadbalancer" {
  source              = "../modules/provider/internal_loadbalancer"
  name                = "dc00app"
  subnet_id           = "${data.azurerm_subnet.subnet.id}"
  resource_group_name = "network-rg"
  location            = "east us 2"

  lb_config = [
     {
       "method"        = "http"
       "frontend_port" = "9000",
       "backend_port"  = "9000",
       "protocol"      = "TCP",
     }
   ]
 
   healthcheck = [
     {
       "name"     = "internal_service_healthcheck",
       "url_path" = "/manage/health"
     }
   ]
 
}
```
... where the app-internal-loadbalancer is the name of the load balancer object in terraform scope. Currently supported providers are:
* azure
* openstack


## Argument Reference
The following arguments are supported:

* admin\_state\_up - (Optional) The administrative state of the monitor. A valid value is true (UP) or false (DOWN).
* delay - (Required) The time, in seconds, between sending probes to members.
* expected\_codes - (Optional) Required for HTTP(S) types. Expected HTTP codes for a passing HTTP(S) monitor. You can either specify a single status like "200", or a range like "200-202".
* http\_method - (Optional) Required for HTTP(S) types. The HTTP method used for requests by the monitor. If this attribute is not specified, it defaults to "GET".
* max\_retries - (Required) Number of permissible ping failures before changing the member's status to INACTIVE. Must be a number between 1 and 10..
* name - (Optional) The Name of the Monitor.
* pool\_id - (Required) The id of the pool that this monitor will be assigned to.
* region - (Optional) The region in which to obtain the V2 Networking client. A Networking client is needed to create an . If omitted, the region argument of the provider is used. Changing this creates a new monitor.
* tenant\_id - (Optional) Required for admins. The UUID of the tenant who owns the monitor. Only administrative users can specify a tenant UUID other than their own. Changing this creates a new monitor.
* timeout - (Required) Maximum number of seconds for a monitor to wait for a ping reply before it times out. The value must be less than the delay value.
* type - (Required) The type of probe, which is PING, TCP, HTTP, or HTTPS, that is sent by the load balancer to verify the member state. Changing this creates a new monitor.
* url\_path - (Optional) Required for HTTP(S) types. URI path that will be accessed if monitor type is HTTP or HTTPS.

## Attributes Reference
The following attributes are exported:

* id - The unique ID for the monitor.
* tenant\_id - See Argument Reference above.
* type - See Argument Reference above.
* delay - See Argument Reference above.
* timeout - See Argument Reference above.
* max\_retries - See Argument Reference above.
* url\_path - See Argument Reference above.
* http\_method - See Argument Reference above.
* expected\_codes - See Argument Reference above.
* admin\_state\_up - See Argument Reference above.

