###############################################################################
# VPC — Custom VPC-Native Network (no auto subnets)
###############################################################################

resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  description = "VPC-native network for GKE private cluster ${var.cluster_name}"
}

###############################################################################
# Subnet — with secondary IP ranges for Pods and Services
###############################################################################

resource "google_compute_subnetwork" "gke_subnet" {
  project       = var.project_id
  name          = "${var.cluster_name}-subnet"
  network       = google_compute_network.vpc.id
  region        = var.region
  ip_cidr_range = "10.0.0.0/24"

  # Alias IP ranges are required for VPC-native (IP masquerade-free) clusters
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.100.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.101.0.0/20"
  }

  # Enable Private Google Access so nodes can reach Google APIs without a public IP
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

###############################################################################
# Cloud Router — required for Cloud NAT
###############################################################################

resource "google_compute_router" "nat_router" {
  project = var.project_id
  name    = "${var.cluster_name}-router"
  network = google_compute_network.vpc.id
  region  = var.region
}

###############################################################################
# Cloud NAT — provides outbound internet access for private nodes
# (node pool has no external IPs; egress routes through NAT)
###############################################################################

resource "google_compute_router_nat" "nat" {
  project                            = var.project_id
  name                               = "${var.cluster_name}-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
