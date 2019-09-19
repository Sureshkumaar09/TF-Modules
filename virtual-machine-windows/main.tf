locals {
  automation_username      = "${lookup(var.bootstrap_config, "automation_username", "deployer")}"
  automation_user_id       = "${lookup(var.bootstrap_config, "automation_user_id", "")}"
  automation_environment   = "${lookup(var.bootstrap_config, "automation_environment", "")}"
  automation_template_path = "/automation/github/${lookup(var.bootstrap_config, "automation_environment", "")}/hcm-chef-automation/platform/rundeck-jobs/chef-full.erb"
  name_servers             = "${lookup(var.bootstrap_config, "name_servers", "")}"
  automation_mount         = "${lookup(var.bootstrap_config, "automation_mount", "")}"
  roaming_mount            = "${lookup(var.bootstrap_config, "roaming_mount", "")}"
  public_key               = "${file("/home/${local.automation_username}/.ssh/id_rsa.pub")}"
  dc                       = "${lookup(var.bootstrap_config, "dc", "")}"
  suse_repo                = "${lookup(var.bootstrap_config, "suse_repo", "")}"
  role                     = "${lookup(var.bootstrap_config, "role", "hcm_platform_os_setup")}"
}

resource "openstack_networking_port_v2" "instance_port" {
  network_id     = "${var.network_id}"
  count          = "${var.num}"
  admin_state_up = "true"
  security_group_ids = "${var.security_group_ids}"
}

#resource "openstack_networking_port_v2" "cifs_port" {
#  network_id     = "${data.openstack_networking_network_v2.storage.id}"
#  count          = "${var.num}"
# admin_state_up = "true"
#  security_group_ids = [
#    "${data.openstack_networking_secgroup_v2.default.id}", "${data.openstack_networking_secgroup_v2.mgmt.id}"
#  ]
#}

resource "openstack_compute_instance_v2" "instance" {
  name              = "${var.num_start == "0" ? "${var.name}${format("%02d", count.index+1)}" : "${var.name}${format("%02d", count.index+1+var.num_start)}"}"
  count             = "${var.num}"
  image_name        = "${var.image_name}"
  flavor_name       = "${var.vm_size}"
  availability_zone = "${element(var.availability_zone, count.index)}"

  network {
    port = "${openstack_networking_port_v2.instance_port.*.id[count.index]}"
    access_network = true
  }

 metadata = { admin_pass = "${var.admin_password}" }
}

resource "openstack_blockstorage_volume_v2" "hdd_data_disk" {
  count = "${var.hdd_disk_count * var.num}"
  availability_zone = "${element(var.availability_zone, count.index)}"
  name  = "${element(openstack_compute_instance_v2.instance.*.name, count.index % var.num)}-vol${format("%02d", count.index + 1)}"
  size = "${var.hdd_disk_size_gb}"
  timeouts {
    create = "60m"
    delete = "20m"
  }
}

resource "openstack_compute_volume_attach_v2" "hdd_data_disk_attachment" {
  count = "${var.hdd_disk_count * var.num}"
  instance_id = "${element(openstack_compute_instance_v2.instance.*.id,count.index)}"
  volume_id   = "${element(openstack_blockstorage_volume_v2.hdd_data_disk.*.id, count.index)}"
  timeouts {
    create = "60m"
    delete = "20m"
  }

 lifecycle {
    ignore_changes = ["volume_id", "instance_id"]
  }
}

resource "template_file" "init" {
  template = "${file("${path.module}/init.tpl")}"
  vars = {
    admin_password = "${var.admin_password}"
    primary_name_server = "${var.primary_name_server}"
    secondary_name_server = "${var.secondary_name_server}"
  }
}

resource "null_resource" "init_script_copy" {
  count = "${var.num}"
  provisioner "file" {
    content     = "${template_file.init.rendered}"
    destination = "C:/init.ps1"
  connection {
        host     = "${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4,count.index)}"
        type     = "winrm"
        user     = "${var.win_admin_username}"
        password = "${var.admin_password}"
        timeout  = "20m"
      }
    }
  }



resource "null_resource" "init_script_run" {
  depends_on = [ "null_resource.init_script_copy" ]
  count = "${var.num}"
  provisioner "remote-exec" {
    inline = [
     "PowerShell.exe -NonInteractive -ExecutionPolicy Unrestricted -File \"C:/init.ps1\"",
     "C:\\Windows\\System32\\cmd.exe /C shutdown -r"
    ]
      connection {
        host     = "${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4,count.index)}"
        type     = "winrm"
        user     = "${var.win_admin_username}"
        password = "${var.admin_password}"
        timeout  = "20m"
      }
    }
  }

resource "null_resource" "wait_after_reboot" {
  depends_on = [ "null_resource.init_script_run" ]
  count = "${var.num}"
  provisioner "local-exec" {
    command = "sleep 120"
  }
}

resource "null_resource" "chef_bootstrap" {
  count = "${var.num}"
  depends_on = [ "null_resource.wait_after_reboot" ]
  provisioner "local-exec" {
    command = "/opt/chefdk/embedded/bin/knife bootstrap windows winrm -m ${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4,count.index)} -N ${element(openstack_compute_instance_v2.instance.*.name,count.index)} -x ${element(openstack_compute_instance_v2.instance.*.name,count.index)}\\\\${var.win_admin_username} -P '${var.admin_password}' --server-url ${var.chef_server_url} --msi-url ${var.yum_repo_url}/hcm/platform/chef/chef-client/chef-client-12.22.5-1-x64.msi -E ${var.chef_environment} --bootstrap-version 12.22.5 --winrm-ssl-verify-mode verify_none"
  }
}

resource "null_resource" "windows_platform_install" {
  depends_on = ["null_resource.chef_bootstrap"]
  count      = "${var.num}"

  provisioner "local-exec" {
    command = "/opt/chefdk/embedded/bin/knife winrm -m ${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4,count.index)} -x ${var.win_admin_username} -P '${var.admin_password}' 'chef-client -o recipe[hcm_platform]'"
  }
}

resource "null_resource" "wait_for_reboot_and_rerun_last" {
  depends_on = ["null_resource.windows_platform_install"]
  count      = "${var.num}"

  provisioner "local-exec" {
    command = "sleep 120; /opt/chefdk/embedded/bin/knife winrm -m ${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4,count.index)} -x ${var.win_admin_username} -P '${var.admin_password}' 'chef-client -o recipe[hcm_platform]'"
  }
}

#resource "null_resource" "windows_update" {
#  depends_on = ["null_resource.wait_for_reboot_and_rerun_last"]
#  count      = "${var.num}"
#  provisioner "local-exec" {
#    command = "sleep 120; /opt/chefdk/embedded/bin/knife winrm -m ${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4,count.index)} -x ${var.win_admin_username} -P '${var.admin_password}' 'chef-client -o recipe[hcm_platform::windows_update]'"
#  }
#}

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
