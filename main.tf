resource "libvirt_pool" "ep2_pool" {
  name = "ep2_pool"
  type = "dir"
  path = "/var/lib/libvirt/images/ep2-pool"
}

# 2. ดึง Ubuntu 22.04 Cloud Image มาเก็บใน Pool
resource "libvirt_volume" "ep2_ubuntu_base" {
  name   = "ep2_ubuntu_base.qcow2"
  pool   = libvirt_pool.ep2_pool.name
  source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

# 3. Cloud-init: สร้าง ISO สำหรับส่งค่า Config (User & SSH Key) เข้าไปในเครื่อง
resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "ep2-commoninit.iso"
  pool      = libvirt_pool.ep2_pool.name
  user_data = <<EOF
#cloud-config
users:
  - name: jira
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCR3cJ7foBqE5m6Bitg1xebwkzHux9Hgh4zJzGwxH2kzdAb91ml6M+df/xyKG6uEEUkHKVLXdiSj2BT6p9mCFMs9ljRnJbVH4MMutM/UVyiXtu+Lcii2ibPtL3hTe8zHO65cMWSlTTeLYJPV3veEJ0mBObOSm47qzpaaVdYtgkgJgMj5qqx9k7NPvhWAaIp8JqRefj5aywbuMkwilvusi8iue0Kn/rdioVn9aQldOt1GmmuDjxZHjHX92Uhtf7e7y9KZesVvNrV915ALKCbXblB4y70EaRIxNj5pLOeJXaFemSw1bekimVhHzGylutg9h+xeaMHAM9JUSkUAixfGRGWVKH9UQHAOQyZ780AAysdVF14hY1GFbGWrsEyIEyg/e/JmSpvyEalSOhP7r+UlJtoGJDg+xRHW8M9SBzIGX1nA8JzqMGqzNgYYQ2Twlkde/fP+p38NT4s8Y/gkgHe1HKWZ0CQfk2oFtKSP7/TH5ZvDew0XrFHCw5DTsNeTADNiQszHVIhsWCIoJAx9gsdBtU/3oSurX/8ZrKqqsvmhlADzhRwJ0RJjNoLEIuYuKu4T2uXC87yeszjKS42j3AhDNEGacmZ/D5M0WJ3BTESsBa9Mwdh2nGxHk9OdUS1oJbGP34zqVFnOzdaxz8OPmLOwDCKrUy3c/Wuzg4sCT3KwG9Iow== jira@hobgoblin
chpasswd:
  list: |
     jira:yulin04
  expire: False
EOF
}

# 4. สร้างตัวเครื่อง VM (Master Node)
resource "libvirt_domain" "ep2_master" {
  name   = "ep2-master-hardened"
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.ep2_ubuntu_base.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
}
