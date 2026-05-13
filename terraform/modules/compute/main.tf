# --- terraform/modules/compute/main.tf ---

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6" # ระบุเวอร์ชันให้ตรงกับที่ติดตั้งไปครับ
    }
  }
}
# Modules ที่เราจะใช้ใน main.tf หลัก (ALL VM and Disk จะถูกสร้างที่นี่) 
#โดยจะรับค่าต่าง ๆ จาก main.tf หลักของแต่ละ environment
#(เช่น local-hob) จะส่งค่าต่าง ๆ มาให้ เช่น pool_name, dmz_net_id, isolated_net_id
# 1. สร้าง Volume (Hard Disk) จาก Image ที่โหลดมา
resource "libvirt_volume" "ep2_ubuntu_base" {
  name   = "ep2_ubuntu_base.qcow2"
  pool   = var.pool_name # ระบุชื่อ pool ที่เราสร้างไว้ใน main.tf หลัก
  source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

# 2. ตัวที่เราจะขยายร่างจริง (Master Root Disk)
resource "libvirt_volume" "ep2_master_disk" {
  name           = "ep2_master_root.qcow2"
  pool           = var.pool_name # ระบุชื่อ pool ที่เราสร้างไว้ใน main.tf หลัก
  base_volume_id = libvirt_volume.ep2_ubuntu_base.id # อ้างอิงจากตัวบน
  size           = 21474836480                       # ขยายเป็น 20GB ตรงนี้แทน!
  format         = "qcow2"
}

# 2. Cloud-init: สร้าง ISO สำหรับส่ง SSH Key เข้าไป (ไม่ต้องใช้ Password)
resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "ep2-commoninit.iso"
  pool      = "ep2_pool"
  user_data = <<EOF
#cloud-config
users:
  - name: jira
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: "password123" 
    chpasswd: { expire: False }
    ssh_authorized_keys:
      - ${file("/home/jira/.ssh/id_rsa.pub")} # ใส่ Public Key
write_files:
  - path: /etc/netplan/50-cloud-init.yaml
    content: |
      network:
        version: 2
        ethernets:
          ens3:
            dhcp4: true
            dhcp-identifier: mac
          ens4:
            dhcp4: true
            optional: true
EOF
}

# 3. สร้างตัวเครื่อง VM (Master Node)
resource "libvirt_domain" "ep2_master" {
  name   = "ep2-master-hardened"
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    # ใช้ ID ของเน็ตเวิร์กที่ส่งมาจากหัวหน้า (Orchestrator)
    network_id = var.isolated_net_id 
  }

disk {
    volume_id = libvirt_volume.ep2_master_disk.id # เปลี่ยนมาชี้ที่ตัวที่ขยายร่างแล้ว
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}
# 4.1 สร้าง Volume สำหรับ Bastion Host (Jump Server)
resource "libvirt_volume" "ep2_bastion_disk" {
  name           = "ep2_bastion_root.qcow2"
  pool           = var.pool_name # ระบุชื่อ pool ที่เราสร้างไว้ใน main.tf หลัก
  base_volume_id = libvirt_volume.ep2_ubuntu_base.id # อ้างอิงจากตัวบน
  size           = 10737418240                       # ขยายเป็น 10GB ตรงนี้แทน!
  format         = "qcow2"
}


# 4.2 build Bastion Host (Jump Server) สำหรับเข้าถึง Master Node จากภายนอก
resource "libvirt_domain" "ep2_bastion" {
  name   = "ep2-bastion-gateway"
  memory = "1024"
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.commoninit.id # use the same cloud-init for simplicity

  network_interface {
    # in DMZ network for external access (act like a Nat Gateway)
    network_id = var.dmz_net_id 
  }

  network_interface {
    # in Isolated network to access Master Node (act like a Jump Server)
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
