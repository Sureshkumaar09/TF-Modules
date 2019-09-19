# https://github.wdf.sap.corp/gist/d072924/bfdf7bfb8258dd4534dc0e23943dd191
# https://documentation.global.cloud.sap/docs/learn/terraform/provision-baremetal.html
# https://documentation.global.cloud.sap/docs/servers/baremetal_config.html

#openstack has a bug with security group, so re-apply will most likely ask for changes when it's unneccessary (if using ids)
#https://github.com/terraform-providers/terraform-provider-openstack/issues/6
#https://github.com/terraform-providers/terraform-provider-openstack/issues/236


locals {
  automation_username      = "${lookup(var.bootstrap_config, "automation_username", "deployer")}"
  automation_user_id       = "${lookup(var.bootstrap_config, "automation_user_id", "")}"
  automation_environment   = "${lookup(var.bootstrap_config, "automation_environment", "")}"
  automation_template_path = "/automation/github/dc${var.dc}_platform_admin/hcm-chef-automation/platform/rundeck-jobs/chef-full.erb"
  name_servers             = "${lookup(var.bootstrap_config, "name_servers", "")}"
  automation_mount         = "${lookup(var.bootstrap_config, "automation_mount", "")}"
  roaming_mount            = "${lookup(var.bootstrap_config, "roaming_mount", "")}"
  public_key               = "${file("/home/${local.automation_username}/.ssh/id_rsa.pub")}"
  dc                       = "${lookup(var.bootstrap_config, "dc", var.dc)}"
  suse_repo                = "${lookup(var.bootstrap_config, "suse_repo", "")}"
  region                   = "${var.region}"
  role                     = "${var.platform_cookbook_role}"
  #disk_size_list           = "${compact(split(",", var.hdd_disk_size_gb))}"
  interface_num            = "${var.interface_num}"
  shared_filesystem_mount_list = "${compact(split(",", var.shared_filesystem_mount_list))}"
  nfs_export_locations = "${compact(split(",", var.nfs_export_locations))}"
  nfs_mount_list = "${compact(split(",", var.nfs_mount_list))}"
  node_specific_shared_filesystem_mount_list = "${compact(split(",", var.node_specific_shared_filesystem_mount_list))}"
}


resource "openstack_networking_port_v2" "nfs_port" {
  network_id     = "${data.openstack_networking_network_v2.storage.id}"
  device_id      = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
  device_owner   = "${data.openstack_networking_port_v2.bm_ports[count.index * local.interface_num].device_owner}"
  count          = "${var.num}"
  admin_state_up = "true"
  
  security_group_ids = [
    "${data.openstack_networking_secgroup_v2.storage.id}"
  ]

  binding {
    host_id   = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
    vnic_type = "${data.openstack_networking_port_v2.bm_ports[count.index * local.interface_num].binding.0.vnic_type}"
    
    profile = "${jsonencode(
      { "vlan_type" : "allowed",
        "local_link_information" : jsondecode(data.external.get_local_link_information[count.index].result.local_link_information)
    })}"   
  }
}



resource "openstack_networking_port_v2" "backup_port" {
  network_id     = "${data.openstack_networking_network_v2.backup.id}"
  count          = "${var.backup_interface * var.num}"
  admin_state_up = "true"
  security_group_ids = "${var.backup_security_group_ids}"
  device_id      = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
  device_owner   = "${data.openstack_networking_port_v2.bm_ports[count.index * local.interface_num].device_owner}"

  binding {
    host_id   = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
    vnic_type = "${data.openstack_networking_port_v2.bm_ports[count.index * local.interface_num].binding.0.vnic_type}"
    
    profile = "${jsonencode(
      { "vlan_type" : "allowed",
       "local_link_information" : jsondecode(data.external.get_local_link_information[count.index].result.local_link_information)
    })}"   
  }
}


resource "openstack_networking_port_v2" "heartbeat_port" {
  network_id     = "${data.openstack_networking_network_v2.heartbeat.id}"
  count          = "${var.heartbeat_interface * var.num}"
  admin_state_up = "true"
  security_group_ids = "${var.heartbeat_security_group_ids}"
  device_id      = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
  device_owner   = "${data.openstack_networking_port_v2.bm_ports[count.index * local.interface_num].device_owner}"
  
  binding {
    host_id   = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
    vnic_type = "${data.openstack_networking_port_v2.bm_ports[count.index * local.interface_num].binding.0.vnic_type}"
    
    profile = "${jsonencode(
      { "vlan_type" : "allowed",
        "local_link_information" : jsondecode(data.external.get_local_link_information[count.index].result.local_link_information)
    })}"   
  }

}



# get the baremetal port ids
data "openstack_networking_port_ids_v2" "bm_ports" {
  count             = "${var.num}"
  device_id  = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
  network_id = "${data.openstack_networking_network_v2.private.id}"
}


# get an info about the baremetal ports and use "local_link_information" for the secondary network
data "openstack_networking_port_v2" "bm_ports" {
  count   = "${local.interface_num * var.num}"
  port_id = "${data.openstack_networking_port_ids_v2.bm_ports[floor(count.index / local.interface_num)].ids[count.index % local.interface_num]}"
}


resource "openstack_compute_instance_v2" "instance" {
  name              = "${replace(var.name,"-","")}${format("%02d", count.index+var.hostname_starting_num)}"
  count             = "${var.num}"
  image_name        = "${var.image_name}"
  flavor_name       = "${var.vm_size}"
  availability_zone = "${element(var.availability_zone, ((count.index+var.hostname_starting_num)-1) % length(var.availability_zone))}"

  security_groups = "${var.security_groups}"

   # define four network interfaces
  dynamic "network" {
    for_each = range(local.interface_num)

    content {
      uuid = "${data.openstack_networking_network_v2.private.id}"
    }
  }

  timeouts {
    create = "60m"
  }

}


# the primary network bonding config for SLES12
data "template_file" "bond0" {
  count             = "${var.num}"
  template = <<EOF
BONDING_MASTER=yes
BONDING_MODULE_OPTS='mode=802.3ad miimon=1000'
BOOTPROTO=dhcp
STARTMODE=auto
MTU=${data.openstack_networking_network_v2.private.mtu}
LLADDR=${data.external.get_working_interface[count.index].result.mac}
EOF
}


# the secondary network vlan config for SLES12
data "template_file" "bond0_nfs_vlan" {
  count             = "${var.num}"
  template = <<EOF
DEVICE='bond0.storage'
ETHERDEVICE=bond0
BOOTPROTO=dhcp
STARTMODE=auto
MTU=${data.openstack_networking_network_v2.private.mtu - 4} # overhead for the vlan is 4 bytes
LLADDR=${openstack_networking_port_v2.nfs_port[count.index].mac_address}
VLAN_ID=${openstack_networking_port_v2.nfs_port[count.index].binding.0.vif_details["vlan"]}
EOF
}

# the secondary network vlan config for SLES12
data "template_file" "bond0_backup_vlan" {
  count             = "${var.backup_interface * var.num}"
  template = <<EOF
DEVICE='bond0.backup'
ETHERDEVICE=bond0
BOOTPROTO=dhcp
STARTMODE=auto
MTU=${data.openstack_networking_network_v2.private.mtu - 4} # overhead for the vlan is 4 bytes
LLADDR=${openstack_networking_port_v2.backup_port[count.index].mac_address}
VLAN_ID=${openstack_networking_port_v2.backup_port[count.index].binding.0.vif_details["vlan"]}
EOF
}

# the secondary network vlan config for SLES12
data "template_file" "bond0_heartbeat_vlan" {
  count             = "${var.heartbeat_interface * var.num}"
  template = <<EOF
DEVICE='bond0.hbeat'
ETHERDEVICE=bond0
BOOTPROTO=dhcp
STARTMODE=auto
MTU=${data.openstack_networking_network_v2.private.mtu - 4} # overhead for the vlan is 4 bytes
LLADDR=${openstack_networking_port_v2.heartbeat_port[count.index].mac_address}
VLAN_ID=${openstack_networking_port_v2.heartbeat_port[count.index].binding.0.vif_details["vlan"]}
EOF
}




resource "null_resource" "configure_bond0" {
  count             = "${var.num}"
  connection {
     host     = "${data.external.get_working_interface[count.index].result.ipv4}"
     type     = "ssh"
     user     = "${var.admin_username}"
     password = "${var.admin_password}"
     timeout  = "30m"
   }

  # the primary bonding config
  provisioner "file" {
    content     = "${data.template_file.bond0[count.index].rendered}"
    destination = "/tmp/ifcfg-bond0"
  }


  # the secondary bonding config
  provisioner "file" {
    content     = "${data.template_file.bond0_nfs_vlan[count.index].rendered}"
    destination = "/tmp/ifcfg-bond0.storage"
  }
}

resource "null_resource" "configure_bond0_backup" {
  count             = "${var.num}"
  connection {
     host     = "${data.external.get_working_interface[count.index].result.ipv4}"
     type     = "ssh"
     user     = "${var.admin_username}"
     password = "${var.admin_password}"
     timeout  = "30m"
   }

   depends_on = [ "null_resource.configure_bond0" ]

   provisioner "file" {
    content     = "${data.template_file.bond0_backup_vlan[count.index].rendered}"
    destination = "/tmp/ifcfg-bond0.backup"
  }
}

resource "null_resource" "configure_bond0_heartbeat" {
  count             = "${var.num}"
  connection {
     host     = "${data.external.get_working_interface[count.index].result.ipv4}"
     type     = "ssh"
     user     = "${var.admin_username}"
     password = "${var.admin_password}"
     timeout  = "30m"
   }

   depends_on = [ "null_resource.configure_bond0" ]

   provisioner "file" {
    content     = "${data.template_file.bond0_heartbeat_vlan[count.index].rendered}"
    destination = "/tmp/ifcfg-bond0.hbeat"
  }

}


resource "null_resource" "configure_network" {
  count             = "${var.num}"
  connection {
     host     = "${data.external.get_working_interface[count.index].result.ipv4}"
     type     = "ssh"
     user     = "${var.admin_username}"
     password = "${var.admin_password}"
     timeout  = "30m"
   }

  depends_on = [ "null_resource.configure_bond0", "null_resource.configure_bond0_backup", "null_resource.configure_bond0_heartbeat" ] 

  # detect the linux interface names, put them into the generated network config files
  # and restart the network
  provisioner "remote-exec" {
    inline = [
<<EOF
k=0
for i in $(find /sys/class/net -type l -not -lname '*virtual*' -printf '%f\n')
do 
echo "BONDING_SLAVE$k=$i" >> /tmp/ifcfg-bond0
# make a backup of an old config
sudo cp -p "/etc/sysconfig/network/ifcfg-$i"{,.bak}
echo -e "STARTMODE=hotplug\nBOOTPROTO=none" | sudo tee "/etc/sysconfig/network/ifcfg-$i"
k=$((k+1))
done
sudo cp /tmp/ifcfg-bond0 /etc/sysconfig/network/ifcfg-bond0
if [ -f /tmp/ifcfg-bond0.storage ]; then
  sudo cp /tmp/ifcfg-bond0.storage /etc/sysconfig/network/ifcfg-bond0.storage
fi
if [ -f /tmp/ifcfg-bond0.backup ]; then
  sudo cp /tmp/ifcfg-bond0.backup /etc/sysconfig/network/ifcfg-bond0.backup
fi
if [ -f /tmp/ifcfg-bond0.hbeat ]; then
  sudo cp /tmp/ifcfg-bond0.hbeat /etc/sysconfig/network/ifcfg-bond0.hbeat
fi
sudo rm -f /etc/systemd/system/create-ifcfg@.service
sudo systemctl daemon-reload
sudo systemctl restart network
EOF
]
}

}



resource "openstack_networking_floatingip_v2" "fip" {
  count = "${var.floatingip == "" || var.floatingip == "false" ? 0: var.num}"
  pool = "${var.floatingip_network}"
  subnet_id = "${data.openstack_networking_subnet_v2.floatingip.id}"
}

resource "openstack_compute_floatingip_associate_v2" "fip" {
  count = "${var.floatingip == "" || var.floatingip == "false" ? 0: var.num}"
  floating_ip = "${openstack_networking_floatingip_v2.fip.*.address[count.index]}"
  instance_id = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
}

resource "openstack_sharedfilesystem_share_access_v2" "set_shared_filesystem_share_access" {
  provider = "openstack.shared_filesystem"
  count            = "${length(var.shared_filesystem_id_list) * var.num}"
  share_id     = "${var.shared_filesystem_id_list[floor(count.index/var.num)]}"
  access_type  = "ip"
  access_to    = "${openstack_networking_port_v2.nfs_port[count.index % var.num].all_fixed_ips[0]}"
  access_level = "${var.share_access_level}"
}

resource "null_resource" "mount_shared_filesystem_export" {
  count = "${length(var.shared_filesystem_export_locations) == length(local.shared_filesystem_mount_list) ? length(var.shared_filesystem_export_locations) * var.num : 0}"
  depends_on = [ "null_resource.configure_network", "openstack_sharedfilesystem_share_access_v2.set_shared_filesystem_share_access"] 

  connection {
    host     = "${data.external.get_working_interface[count.index % var.num].result.ipv4}"
    type     = "ssh"
    user     = "${var.admin_username}"
    password = "${var.admin_password}"
    timeout  = "1m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${local.shared_filesystem_mount_list[floor(count.index/var.num)]}",
      "grep '${local.shared_filesystem_mount_list[floor(count.index/var.num)]}' /etc/fstab || echo '${var.shared_filesystem_export_locations[floor(count.index/var.num)][0]["preferred"] == "true" ? var.shared_filesystem_export_locations[floor(count.index/var.num)][0]["path"] : var.shared_filesystem_export_locations[floor(count.index/var.num)][1]["path"]}   ${local.shared_filesystem_mount_list[floor(count.index/var.num)]}   ${var.nfs_mount_option}' | sudo tee -a /etc/fstab",
      "sudo mount ${local.shared_filesystem_mount_list[floor(count.index/var.num)]}"
    ]
  }

}

resource "openstack_sharedfilesystem_share_access_v2" "set_node_specific_shared_filesystem_share_access" {
  provider = "openstack.shared_filesystem"
  count            = "${length(var.node_specific_shared_filesystem_id_list)}"
  share_id     = "${var.node_specific_shared_filesystem_id_list[count.index % var.num]}"
  access_type  = "ip"
  access_to    = "${openstack_networking_port_v2.nfs_port[count.index % var.num].all_fixed_ips[0]}"
  access_level = "${var.share_access_level}"
}

resource "null_resource" "mount_node_specific_shared_filesystem_export" {
  count = "${length(var.node_specific_shared_filesystem_export_locations) == length(local.node_specific_shared_filesystem_mount_list) ? length(var.node_specific_shared_filesystem_export_locations) : 0}"
  depends_on = [ "null_resource.configure_network" , "openstack_sharedfilesystem_share_access_v2.set_node_specific_shared_filesystem_share_access"] 

  connection {
    host     = "${data.external.get_working_interface[count.index % var.num].result.ipv4}"
    type     = "ssh"
    user     = "${var.admin_username}"
    password = "${var.admin_password}"
    timeout  = "1m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${local.node_specific_shared_filesystem_mount_list[count.index % var.num]}",
      "grep '${local.node_specific_shared_filesystem_mount_list[count.index % var.num]}' /etc/fstab || echo '${var.node_specific_shared_filesystem_export_locations[count.index % var.num][0]["preferred"] == "true" ? var.node_specific_shared_filesystem_export_locations[count.index % var.num][0]["path"] : var.node_specific_shared_filesystem_export_locations[count.index % var.num][1]["path"]}   ${local.node_specific_shared_filesystem_mount_list[count.index % var.num]}   ${var.nfs_mount_option}' | sudo tee -a /etc/fstab",
      "sudo mount ${local.node_specific_shared_filesystem_mount_list[count.index % var.num]}"
    ]
  }

}


resource "null_resource" "mount_nfs_shares" {
  count = "${length(local.nfs_export_locations) == length(local.nfs_mount_list) ? length(local.nfs_export_locations) * var.num : 0}"
  depends_on = [ "null_resource.configure_network" ] 

  connection {
    host     = "${data.external.get_working_interface[count.index % var.num].result.ipv4}"
    type     = "ssh"
    user     = "${var.admin_username}"
    password = "${var.admin_password}"
    timeout  = "1m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${local.nfs_mount_list[floor(count.index/var.num)]}",
      "grep '${local.nfs_mount_list[floor(count.index/var.num)]}' /etc/fstab || echo '${local.nfs_export_locations[floor(count.index/var.num)]}   ${local.nfs_mount_list[floor(count.index/var.num)]}   ${var.nfs_mount_option}' | sudo tee -a /etc/fstab",
      "sudo mount ${local.nfs_mount_list[floor(count.index/var.num)]}"
    ]
  }

}

resource "null_resource" "init_script" {
  count = "${var.num}"

  depends_on = [ "null_resource.configure_network" ] 

  connection {
    host     = "${data.external.get_working_interface[count.index].result.ipv4}"
    type     = "ssh"
    user     = "${var.admin_username}"
    password = "${var.admin_password}"
    timeout  = "1m"
  }

  provisioner "local-exec" {
    command    = "sed -i '/${data.external.get_working_interface[count.index].result.ipv4}/d' /home/${local.automation_username}/.ssh/known_hosts*"
    on_failure = "continue"
  }

  provisioner "file" {
    source      = "${path.module}/init.sh"
    destination = "/tmp/init.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo -n true &&  sudo sh  /tmp/init.sh -k '${local.public_key}' -i '${local.automation_user_id}' -u '${local.automation_username}' -r '${local.roaming_mount}' -g '${local.region}' -a '${local.automation_mount}' -H '${element(openstack_compute_instance_v2.instance.*.name, count.index)}' -d '${local.dc}' -p '${data.external.get_working_interface[count.index].result.ipv4}' -n '${local.name_servers}' -s '${local.suse_repo}' ",
    ]
  }
}

resource "null_resource" "bootstrap" {
  count = "${var.num}"

  provisioner "local-exec" {
    command = "knife bootstrap ${data.external.get_working_interface[count.index].result.ipv4} -N ${element(openstack_compute_instance_v2.instance.*.name,count.index)} -x  ${local.automation_username} --sudo -i /home/${local.automation_username}/.ssh/id_rsa -E ${local.automation_environment}  -c /home/deployer/.chef/knife.rb --template ${local.automation_template_path}"
  }

  depends_on = ["null_resource.init_script"]
}

resource "null_resource" "run_platform_cookbook" {
  count = "${var.include_platform_install ? var.num : 0}"

  provisioner "remote-exec" {
    inline = [
      "sudo -n true && sudo chef-client -o ${local.role}",
    ]

    connection {
      host        = "${data.external.get_working_interface[count.index].result.ipv4}"
      type        = "ssh"
      user        = "${local.automation_username}"
      timeout     = "1m"
      private_key = "${file("/home/${local.automation_username}/.ssh/id_rsa")}"
    }
  }

  depends_on = ["null_resource.bootstrap"]
}

resource "null_resource" "update_system" {
  count = "${var.update_system== "" || var.update_system == "false" ? 0: var.num }"
  provisioner "remote-exec" {
    inline = [
      "sudo -n true && sudo zypper up -y",
    ]

    connection {
      host        = "${data.external.get_working_interface[count.index].result.ipv4}"
      type        = "ssh"
      user        = "${local.automation_username}"
      timeout     = "1m"
      private_key = "${file("/home/${local.automation_username}/.ssh/id_rsa")}"
    }
  }

  depends_on = ["null_resource.run_platform_cookbook"]
}

resource "null_resource" "remove_dns" {
  count = "${var.num}"

  provisioner "remote-exec" {
    inline = [
      "sudo /usr/bin/kinit -k",
      "sudo /usr/sbin/addns -D -d dc0${local.dc}.sf.priv -n ${element(openstack_compute_instance_v2.instance.*.name,count.index)} -i ${data.external.get_working_interface[count.index].result.ipv4}",
    ]

    connection {
      host        = "${data.external.get_working_interface[count.index].result.ipv4}"
      type        = "ssh"
      user        = "${local.automation_username}"
      timeout     = "1m"
      private_key = "${file("/home/${local.automation_username}/.ssh/id_rsa")}"
    }

    on_failure = "continue"
    when       = "destroy"
  }
}

resource "null_resource" "remove_nodes_from_chef" {
  count = "${var.num}"

  provisioner "local-exec" {
    when = "destroy"

    command = <<EOT
      knife node delete "${element(openstack_compute_instance_v2.instance.*.name,count.index)}" -y
      knife client delete "${element(openstack_compute_instance_v2.instance.*.name,count.index)}"  -y
    EOT

    on_failure = "continue"
  }
}

