# --- terraform/modules/compute/main.tf ---

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6"
    }
  }
}

# =================================================================
# 1. Create Volume (Hard Disk) from loaded Image
# =================================================================
resource "libvirt_volume" "ep2_ubuntu_base" {
  name   = "ep2_ubuntu_base.qcow2"
  pool   = var.pool_name
  source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

# Master Root Disk (20GB)
resource "libvirt_volume" "ep2_master_disk" {
  name           = "ep2_master_root.qcow2"
  pool           = var.pool_name
  base_volume_id = libvirt_volume.ep2_ubuntu_base.id
  size           = 21474836480 
  format         = "qcow2"
}

# Bastion Root Disk (10GB) - ประกาศตรงนี้รอบเดียวพอครับ!
resource "libvirt_volume" "ep2_bastion_disk" {
  name           = "ep2_bastion_root.qcow2"
  pool           = var.pool_name
  base_volume_id = libvirt_volume.ep2_ubuntu_base.id
  size           = 10737418240 
  format         = "qcow2"
}

# =================================================================
# 2. Cloud-init: Create ISO to pass SSH Key
# =================================================================
# แยกไฟล์ ISO ของ Bastion
resource "libvirt_cloudinit_disk" "bastion_init" {
  name      = "ep2-bastion-init.iso"
  pool      = var.pool_name
  user_data = templatefile("${path.module}/../../../cloud-init/bastion.cfg", {
    ssh_key = file("/home/jira/.ssh/id_rsa.pub")
  })
}

# แยกไฟล์ ISO ของ Master
resource "libvirt_cloudinit_disk" "master_init" {
  name      = "ep2-master-init.iso"
  pool      = var.pool_name
  user_data = templatefile("${path.module}/../../../cloud-init/k8s-control-plane.cfg", {
    ssh_key = file("/home/jira/.ssh/id_rsa.pub")
  })
}

# =================================================================
# 3. Create VM instances
# =================================================================

# 🚀 เครื่อง Master Node (หลบอยู่ใน Isolated Net)
resource "libvirt_domain" "ep2_master" {
  name   = "ep2-master-hardened"
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.master_init.id # ✅ แก้เป็นตัวแยกของตัวเองเรียบร้อย

  network_interface {
    network_id = var.isolated_net_id 
  }

  disk {
    volume_id = libvirt_volume.ep2_master_disk.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}

# 🛡️ เครื่อง Bastion Host (Gateway เชื่อมต่อสองฝั่ง)
resource "libvirt_domain" "ep2_bastion" {
  name   = "ep2-bastion-gateway"
  memory = "1024"
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.bastion_init.id # ✅ แก้เป็นตัวแยกของตัวเองเรียบร้อย

  network_interface {
    network_id = var.dmz_net_id 
  }

  network_interface {
    network_id = var.isolated_net_id
  }

  disk {
    volume_id = libvirt_volume.ep2_bastion_disk.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}