# --- terraform/modules/network/outputs.tf ---
# (อย่าลืมสร้างไฟล์นี้ในโมดูล network เพื่อส่งค่าชื่อเน็ตออกไปครับ)
output "dmz_net_name" {
  value = libvirt_network.dmz_net.name
}