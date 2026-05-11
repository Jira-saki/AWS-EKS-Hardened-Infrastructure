# --- terraform/environments/local-hob/main.tf ---

module "network" {
  source = "../../modules/network"
}

module "compute" {
  source = "../../modules/compute"
  dmz_net_id      = module.network.dmz_net_id
  isolated_net_id = module.network.isolated_net_id
}

resource "libvirt_pool" "ep2_pool" {
  name = "ep2_pool"
  type = "dir"
  path = "/var/lib/libvirt/images/ep2-pool"
}






