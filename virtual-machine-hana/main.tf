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
  role                     = "${lookup(var.bootstrap_config, "role", var.platform_cookbook_role)}"
  region                   = "${var.region}"
  #chef_tags                = "${compact(concat(var.chef_tags, var.pool))}"
  disk_size_list           = "${compact(split(",", var.hdd_disk_size_gb))}"
  shared_filesystem_mount_list = "${compact(split(",", var.shared_filesystem_mount_list))}"
  nfs_export_locations = "${compact(split(",", var.nfs_export_locations))}"
  nfs_mount_list = "${compact(split(",", var.nfs_mount_list))}"
  node_specific_shared_filesystem_mount_list = "${compact(split(",", var.node_specific_shared_filesystem_mount_list))}"
}

resource "openstack_networking_port_v2" "instance_port" {
  network_id     = "${var.network_id}"
  count          = "${var.num}"
  admin_state_up = "true"

  security_group_ids = "${var.security_group_ids}"
}

resource "openstack_networking_port_v2" "nfs_port" {
  network_id     = "${data.openstack_networking_network_v2.storage.id}"
  count          = "${var.num}"
  admin_state_up = "true"

  security_group_ids = ["${data.openstack_networking_secgroup_v2.storage.id}"]
}

resource "openstack_networking_port_v2" "backup_port" {
  network_id     = "${data.openstack_networking_network_v2.backup.id}"
  count          = "${var.backup_interface * var.num}"
  admin_state_up = "true"
  security_group_ids = "${var.backup_security_group_ids}"
}
resource "openstack_networking_port_v2" "heartbeat_port" {
  network_id     = "${data.openstack_networking_network_v2.heartbeat.id}"
  count          = "${var.heartbeat_interface * var.num}"
  admin_state_up = "true"
  security_group_ids = "${var.heartbeat_security_group_ids}"
}
resource "openstack_compute_instance_v2" "instance" {
  name              = "${replace(var.name,"-","")}${format("%02d", count.index+var.hostname_starting_num)}${var.name_extension}"
  count             = "${var.num}"
  image_name        = "${var.image_name}"
  flavor_name       = "${var.vm_size}"
  availability_zone = "${element(var.availability_zone, ((count.index+var.hostname_starting_num)-1) % length(var.availability_zone))}"

  network {
    port           = "${openstack_networking_port_v2.instance_port.*.id[count.index]}"
    access_network = true
  }

}

resource "openstack_networking_floatingip_v2" "fip" {
  count     = "${var.floatingip == "" || var.floatingip == "false" ? 0 : var.num}"
  pool      = "${var.floatingip_network}"
  subnet_id = "${data.openstack_networking_subnet_v2.floatingip.id}"
}

resource "openstack_compute_floatingip_associate_v2" "fip" {
  count       = "${var.floatingip == "" || var.floatingip == "false" ? 0 : var.num}"
  floating_ip = "${openstack_networking_floatingip_v2.fip.*.address[count.index]}"
  instance_id = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
}

resource "openstack_compute_interface_attach_v2" "nfs_port_attachment" {
  count             = "${var.num}"
  instance_id = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
  port_id     = "${openstack_networking_port_v2.nfs_port.*.id[count.index]}"

  timeouts {
    create = "10m"
    delete = "10m"
  }
}

resource "openstack_compute_interface_attach_v2" "backup_port_attachment" {
  count          = "${var.backup_interface * var.num}"
  instance_id = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
  port_id     = "${openstack_networking_port_v2.backup_port.*.id[count.index]}"
  depends_on  = ["openstack_compute_instance_v2.instance", "openstack_networking_port_v2.backup_port", "openstack_compute_interface_attach_v2.nfs_port_attachment"]
  timeouts {
    create = "10m"
    delete = "10m"
  }
}
resource "openstack_compute_interface_attach_v2" "heartbeat_port_attachment" {
  count          = "${var.heartbeat_interface * var.num}"
  instance_id = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
  port_id     = "${openstack_networking_port_v2.heartbeat_port.*.id[count.index]}"
  depends_on  = ["openstack_compute_instance_v2.instance", "openstack_networking_port_v2.backup_port", "openstack_compute_interface_attach_v2.nfs_port_attachment"]
  timeouts {
    create = "10m"
    delete = "10m"
  }
}
resource "openstack_blockstorage_volume_v2" "hdd_data_disk" {
  count = "${length(local.disk_size_list) * var.num}"
  availability_zone = "${openstack_compute_instance_v2.instance.*.availability_zone[count.index % var.num]}"
  name  = "${openstack_compute_instance_v2.instance.*.name[count.index % var.num]}-vol${format("%02d",floor(count.index/var.num)+1)}"
  size = "${local.disk_size_list[ floor(count.index/var.num) ]}"
  timeouts {
    create = "60m"
    delete = "20m"
  }
}

resource "openstack_compute_volume_attach_v2" "hdd_data_disk_attachment" {
  count = "${length(local.disk_size_list) * var.num}"
  instance_id = "${openstack_compute_instance_v2.instance.*.id[count.index % var.num]}"
  volume_id   = "${openstack_blockstorage_volume_v2.hdd_data_disk.*.id[count.index]}"
  timeouts {
    create = "60m"
    delete = "20m"
  }
   depends_on  = ["openstack_compute_instance_v2.instance", "openstack_blockstorage_volume_v2.hdd_data_disk"]

  lifecycle {
    ignore_changes = ["volume_id", "instance_id"]
  }
}

resource "null_resource" "setup_nfs_interface" {
  count          = "${var.num}"
  depends_on  = ["openstack_compute_instance_v2.instance", "openstack_blockstorage_volume_v2.hdd_data_disk", "openstack_compute_volume_attach_v2.hdd_data_disk_attachment","openstack_compute_interface_attach_v2.nfs_port_attachment"]
  provisioner "remote-exec" {
    connection {
     host     = "${openstack_compute_instance_v2.instance[count.index].network[0].fixed_ip_v4}"
     type     = "ssh"
     user     = "${var.admin_username}"
     password = "${var.admin_password}"
     timeout  = "1m"
   }
    inline = [
      "sudo cp /etc/sysconfig/network/ifcfg-eth0 /etc/sysconfig/network/ifcfg-eth1"
    ]
  }
}
resource "null_resource" "setup_backup_interface" {
  count          = "${var.backup_interface * var.num}"
  depends_on  = ["openstack_compute_instance_v2.instance", "openstack_blockstorage_volume_v2.hdd_data_disk", "openstack_compute_volume_attach_v2.hdd_data_disk_attachment","openstack_compute_interface_attach_v2.backup_port_attachment"]
  provisioner "remote-exec" {
    connection {
     host     = "${openstack_compute_instance_v2.instance[count.index].network[0].fixed_ip_v4}"
     type     = "ssh"
     user     = "${var.admin_username}"
     password = "${var.admin_password}"
     timeout  = "1m"
   }
    inline = [
      "sudo cp /etc/sysconfig/network/ifcfg-eth0 /etc/sysconfig/network/ifcfg-eth2"
    ]
  }
}
resource "null_resource" "setup_heartbeat_interface" {
  count          = "${var.heartbeat_interface * var.num}"
  depends_on  = ["openstack_compute_instance_v2.instance", "openstack_blockstorage_volume_v2.hdd_data_disk", "openstack_compute_volume_attach_v2.hdd_data_disk_attachment","openstack_compute_interface_attach_v2.heartbeat_port_attachment"]
  provisioner "remote-exec" {
    connection {
     host     = "${openstack_compute_instance_v2.instance[count.index].network[0].fixed_ip_v4}"
     type     = "ssh"
     user     = "${var.admin_username}"
     password = "${var.admin_password}"
     timeout  = "1m"
   }
    inline = [
      "sudo cp /etc/sysconfig/network/ifcfg-eth0 /etc/sysconfig/network/ifcfg-eth3"
    ]
  }
}
resource "null_resource" "restart_network" {
  count          = "${var.num}"
  depends_on  = ["null_resource.setup_nfs_interface", "null_resource.setup_backup_interface", "null_resource.setup_heartbeat_interface"]
  provisioner "remote-exec" {
    connection {
     host     = "${openstack_compute_instance_v2.instance[count.index].network[0].fixed_ip_v4}"
     type     = "ssh"
     user     = "${var.admin_username}"
     password = "${var.admin_password}"
     timeout  = "1m"
   }
    inline = [
      "sudo systemctl restart network"
    ]
  }
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
  depends_on = [ "null_resource.restart_network", "openstack_sharedfilesystem_share_access_v2.set_shared_filesystem_share_access" ] 

  connection {
    host     = "${openstack_compute_instance_v2.instance[count.index % var.num].network[0].fixed_ip_v4}"
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
  depends_on = [ "null_resource.restart_network", "openstack_sharedfilesystem_share_access_v2.set_node_specific_shared_filesystem_share_access" ] 

  connection {
    host     = "${openstack_compute_instance_v2.instance[count.index % var.num].network[0].fixed_ip_v4}"
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
  depends_on = [ "null_resource.restart_network" ] 

  connection {
    host     = "${openstack_compute_instance_v2.instance[count.index % var.num].network[0].fixed_ip_v4}"
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
  depends_on = [ "null_resource.restart_network" ] 

  connection {
    host     = "${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4, count.index)}"
    type     = "ssh"
    user     = "${var.admin_username}"
    password = "${var.admin_password}"
    timeout  = "1m"
  }

  provisioner "local-exec" {
    command    = "sed -i '/${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4, count.index)}/d' /home/${local.automation_username}/.ssh/known_hosts*"
    on_failure = "continue"
  }

  provisioner "file" {
    source      = "${path.module}/init.sh"
    destination = "/tmp/init.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo -n true &&  sudo sh  /tmp/init.sh -k '${local.public_key}' -i '${local.automation_user_id}' -u '${local.automation_username}' -r '${local.roaming_mount}' -g '${local.region}' -a '${local.automation_mount}' -H '${element(openstack_compute_instance_v2.instance.*.name, count.index)}' -d '${local.dc}' -p '${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4, count.index)}' -n '${local.name_servers}' -s '${local.suse_repo}' ",
    ]
  }
}

resource "null_resource" "bootstrap" {
  count = "${var.num}"

  provisioner "local-exec" {
    command = "knife bootstrap ${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4, count.index)} -N ${element(openstack_compute_instance_v2.instance.*.name, count.index)} -x  ${local.automation_username} --sudo -i /home/${local.automation_username}/.ssh/id_rsa -E ${local.automation_environment}  -c /home/deployer/.chef/knife.rb --template ${local.automation_template_path}"
  }

  depends_on = ["null_resource.init_script"]
}

#Creating Knife Tags
#resource "null_resource" "knife_tag" {
#  count = "${var.chef_tags == "" ? 0 : var.num}"

#  provisioner "local-exec" {
#    command = "knife tag create ${element(openstack_compute_instance_v2.instance.*.name, count.index)} ${local.chef_tags} ${replace(local.chef_tags, ",", " ")} -c /home/${local.automation_username}/.chef/knife.rb"
#  }
#
#  depends_on = ["null_resource.bootstrap"]
#}

resource "null_resource" "run_platform_cookbook" {
  count = "${var.include_platform_install ? var.num : 0}"

  provisioner "remote-exec" {
    inline = [
      "sudo -n true && sudo chef-client -o ${local.role}",
    ]

    connection {
      host        = "${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4, count.index)}"
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
      host        = "${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4, count.index)}"
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
      "sudo /usr/sbin/addns -D -d dc0${local.dc}.sf.priv -n ${element(openstack_compute_instance_v2.instance.*.name, count.index)} -i ${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4, count.index)}",
    ]

    connection {
      host        = "${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4, count.index)}"
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
      knife node delete "${element(openstack_compute_instance_v2.instance.*.name, count.index)}" -y
      knife client delete "${element(openstack_compute_instance_v2.instance.*.name, count.index)}"  -y
    EOT

    on_failure = "continue"
  }
}
