# --- terraform/modules/network/main.tf ---

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6" # ล็อกเวอร์ชันให้ตรงกับที่เครื่อง Hobgoblin ใช้ครับ
    }
  }
}

# 1. DMZ Network (เน็ตขาเข้า/Public Zone)
resource "libvirt_network" "dmz_net" {
  name      = "dmz-net"
  mode      = "nat"          # ให้ออกเน็ตได้ผ่าน Host
  domain    = "dmz.local"
  addresses = ["192.168.150.0/24"]

  dns {
    enabled    = true
    local_only = false      # ยอมให้ Resolve DNS จากข้างนอกได้
  }
  autostart = true
}

# 2. Isolated Network (เน็ตขาใน/Private Zone)
resource "libvirt_network" "isolated_net" {
  name      = "isolated-net"
  mode      = "none"         # Isolated: ปิดตาย ไม่มีการ Route ออกข้างนอก
  domain    = "isolated.local"
  addresses = ["192.168.200.0/24"]

  dns {
    enabled    = true
    local_only = true       # Resolve เฉพาะภายในโซนนี้เท่านั้น
  }
  autostart = true
}

#--- ส่งค่าออกไปให้ Module อื่นเรียกใช้ (Output) ---
output "dmz_net_name" {
  value = libvirt_network.dmz_net.name
}

output "isolated_net_name" {
  value = libvirt_network.isolated_net.name
}