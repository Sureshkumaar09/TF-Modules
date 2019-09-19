locals {
  automation_username      = "${lookup(var.bootstrap_config, "automation_username", "deployer")}"
  automation_user_id       = "${lookup(var.bootstrap_config, "automation_user_id", "")}"
  automation_environment   = "${lookup(var.bootstrap_config, "automation_environment", "")}"
  automation_template_path = "/automation/github/dc${var.dc}_platform_admin/hcm-chef-automation/platform/rundeck-jobs/chef-full.erb"
  name_servers             = "${lookup(var.bootstrap_config, "name_servers", "")}"
  automation_mount         = "${lookup(var.bootstrap_config, "automation_mount", "")}"
  roaming_mount            = "${lookup(var.bootstrap_config, "roaming_mount", "")}"
  public_key               = "${file("/home/${local.automation_username}/.ssh/id_rsa.pub")}"
  dc                       = "${lookup(var.bootstrap_config, "dc", "")}"
  suse_repo                = "${lookup(var.bootstrap_config, "suse_repo", "")}"
  role                     = "${lookup(var.bootstrap_config, "role", "recipe[hcm_os_hardening],recipe[hcm_platform_ohai],recipe[hcm_platform_base::setup_syslog],recipe[hcm_platform_base::create_repositories],recipe[hcm_platform_base::install_packages],recipe[hcm_platform_mounts],recipe[hcm_platform_base::create_directories],recipe[hcm_platform_base::create_users],recipe[hcm_platform_base::add_tags],recipe[hcm_platform_zabbix],recipe[hcm_platform_beat],recipe[hcm_platform_mail],recipe[hcm_platform_sssd],recipe[hcm_platform_splunk::install_splunk_forwarder],recipe[hcm_platform_monsoon],recipe[hcm_platform_mcafee],recipe[hcm_platform_sumareg]")}"
  region                   = "${var.region}"

  #chef_tags                = "${compact(concat(var.chef_tags, var.pool))}"
  index_start             = "${var.index_start == "" ? 1 : var.index_start}"
}

resource "openstack_networking_port_v2" "instance_port" {
  network_id     = "${var.network_id}"
  count          = "${var.num}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = var.subnet_id
  }

  security_group_ids = concat(
    ["${data.openstack_networking_secgroup_v2.default.id}"],
    var.security_group_ids
  )
}

resource "openstack_networking_port_v2" "nfs_port" {
  network_id     = "${data.openstack_networking_network_v2.storage.id}"
  count          = "${var.num}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = var.storage_subnet_id
  }

  security_group_ids = [
    "${data.openstack_networking_secgroup_v2.storage.id}",
  ]
}

resource "openstack_compute_instance_v2" "instance" {
  name              = "${replace(var.name, "-", "")}${format("%02d", count.index + local.index_start)}${var.name_extension}"
  count             = "${var.num}"
  image_name        = "${var.image_name}"
  flavor_name       = "${var.vm_size}"
  availability_zone = "${element(var.availability_zone, count.index)}"

  network {
    port           = "${openstack_networking_port_v2.instance_port.*.id[count.index]}"
    access_network = true
  }

  network {
    port = "${openstack_networking_port_v2.nfs_port.*.id[count.index]}"
  }
}


resource "openstack_networking_floatingip_v2" "fip" {
  count       = "${var.floatingip == "" || var.floatingip == "false" ? 0 : var.num}"
  description = element(openstack_compute_instance_v2.instance.*.name, count.index)
  pool        = "${var.floatingip_network}"
  subnet_id   = "${data.openstack_networking_subnet_v2.floatingip_subnet.id}"
}

resource "openstack_compute_floatingip_associate_v2" "fip" {
  count       = "${var.floatingip == "" || var.floatingip == "false" ? 0 : var.num}"
  floating_ip = "${openstack_networking_floatingip_v2.fip.*.address[count.index]}"
  instance_id = "${openstack_compute_instance_v2.instance.*.id[count.index]}"
}

resource "openstack_blockstorage_volume_v2" "hdd_data_disk" {
  count             = "${var.hdd_disk_count == "" || var.hdd_disk_count == "0" ? 0 : var.hdd_disk_count * var.num}"
  availability_zone = "${element(openstack_compute_instance_v2.instance.*.availability_zone, floor(count.index / var.hdd_disk_count))}"
  name              = "${element(openstack_compute_instance_v2.instance.*.name, floor(count.index / var.hdd_disk_count))}-vol${format("%02d", count.index + local.index_start)}"
  size              = "${element(split(",", var.hdd_disk_size_gb), count.index)}"

  timeouts {
    create = "60m"
    delete = "20m"
  }
}

resource "openstack_compute_volume_attach_v2" "hdd_data_disk_attachment" {
  count       = "${var.hdd_disk_count == "" || var.hdd_disk_count == "0" ? 0 : var.hdd_disk_count * var.num}"
  instance_id = "${element(openstack_compute_instance_v2.instance.*.id, floor(count.index / var.hdd_disk_count))}"
  volume_id   = "${element(openstack_blockstorage_volume_v2.hdd_data_disk.*.id, count.index)}"
  device      = "${var.hdd_disk_device}"

  timeouts {
    create = "60m"
    delete = "20m"
  }

  lifecycle {
    ignore_changes = ["volume_id", "instance_id"]
  }
}

resource "null_resource" "init_script" {
  count = "${var.num}"

  connection {
    host     = "${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4, count.index)}"
    type     = "ssh"
    user     = "${var.admin_username}"
    password = "${var.admin_password}"
    timeout  = "10m"
  }

  provisioner "local-exec" {
    command    = "sed -i '/${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4, count.index)}/d' /home/${local.automation_username}/.ssh/known_hosts*"
    on_failure = "continue"
  }

  provisioner "file" {
    source      = "${path.module}/${var.user_data}"
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
  count = "${var.num}"

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

resource "null_resource" "reboot" {
  count = "${var.num}"

  provisioner "remote-exec" {
    inline = [
      "sudo /sbin/shutdown --no-wall -r +1",
    ]

    connection {
      host        = "${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4, count.index)}"
      type        = "ssh"
      user        = "${local.automation_username}"
      timeout     = "1m"
      private_key = "${file("/home/${local.automation_username}/.ssh/id_rsa")}"
    }
  }

  depends_on = ["null_resource.update_system"]
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
