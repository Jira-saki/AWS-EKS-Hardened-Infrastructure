# --- terraform/modules/compute/variables.tf ---

variable "dmz_net_id" {
  type = string
}

variable "isolated_net_id" {
  type = string
}

variable "pool_name" {
  type = string
}

variable "ssh_pub_key_path" {
  type = string
  default = "~/.ssh/id_rsa.pub"
}