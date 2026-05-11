# --- terraform/modules/network/outputs.tf ---

output "dmz_net_id" {
  value = libvirt_network.dmz_net.id
}

output "isolated_net_id" {
  value = libvirt_network.isolated_net.id
}