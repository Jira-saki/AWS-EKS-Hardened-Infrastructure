###############################################################################
# Outputs — GKE Environment
###############################################################################

output "cluster_name" {
  description = "Name of the GKE cluster."
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "Public endpoint of the GKE master API server."
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster (used in kubeconfig)."
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "vpc_name" {
  description = "Name of the VPC network."
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Name of the GKE subnet."
  value       = google_compute_subnetwork.gke_subnet.name
}

output "kms_key_id" {
  description = "Full resource ID of the Cloud KMS CryptoKey used for etcd encryption."
  value       = google_kms_crypto_key.gke_etcd.id
}

output "workload_identity_pool" {
  description = "Workload Identity Pool used by the cluster."
  value       = "${var.project_id}.svc.id.goog"
}

output "secure_api_gsa_email" {
  description = "Email of the GCP Service Account for the secure-api workload."
  value       = google_service_account.secure_api.email
}

output "nat_ip" {
  description = "Auto-allocated Cloud NAT external IP (for allowlisting in external firewalls)."
  value       = google_compute_router_nat.nat.nat_ip_allocate_option
}
