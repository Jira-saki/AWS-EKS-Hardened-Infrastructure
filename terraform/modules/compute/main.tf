# --- terraform/modules/compute/main.tf ---

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6" # Specify version matching the installed one
    }
  }
}
# Modules that we will use in the main main.tf (ALL VM and Disk will be created here)
# It will receive various values from the main main.tf of each environment
# (e.g., local-hob) will pass values like pool_name, dmz_net_id, isolated_net_id
# 1. Create Volume (Hard Disk) from loaded Image
resource "libvirt_volume" "ep2_ubuntu_base" {
  name   = "ep2_ubuntu_base.qcow2"
  pool   = var.pool_name # Specify the pool name we created in the main main.tf
  source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

# 2. The one we will expand as the actual instance (Master Root Disk)
resource "libvirt_volume" "ep2_master_disk" {
  name           = "ep2_master_root.qcow2"
  pool           = var.pool_name # Specify the pool name we created in the main main.tf
  base_volume_id = libvirt_volume.ep2_ubuntu_base.id # Reference from the above
  size           = 21474836480                       # Expand to 20GB here instead!
  format         = "qcow2"
}

# 2. Cloud-init: Create ISO to pass SSH Key (No password needed)
resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "ep2-commoninit.iso"
  pool      = "ep2_pool"
  user_data = <<EOF
#cloud-config
users:
  - name: jira
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    chpasswd: { expire: False }
    ssh_authorized_keys:
      - ${file("/home/jira/.ssh/id_rsa.pub")} # Add public key
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

# 3. Create VM instance (Master Node)
resource "libvirt_domain" "ep2_master" {
  name   = "ep2-master-hardened"
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    # Use the network ID sent from the main controller (Orchestrator)
    network_id = var.isolated_net_id 
  }

disk {
    volume_id = libvirt_volume.ep2_master_disk.id # Changed to point to the expanded instance
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}
# 4.1 Create Volume for Bastion Host (Jump Server)
resource "libvirt_volume" "ep2_bastion_disk" {
  name           = "ep2_bastion_root.qcow2"
  pool           = var.pool_name # Specify the pool name we created in the main main.tf
  base_volume_id = libvirt_volume.ep2_ubuntu_base.id # Reference from the above
  size           = 10737418240                       # Expand to 10GB here instead!
  format         = "qcow2"
}

# 4.2 Build Bastion Host (Jump Server) to access Master Node from outside
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
