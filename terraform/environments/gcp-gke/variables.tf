variable "project_id" {
  description = "GCP Project ID in which all resources will be created."
  type        = string
  # Replace with your actual GCP Project ID before running terraform apply.
  # Example: "my-gcp-project-123"
}

variable "project_number" {
  description = "GCP Project Number (numeric). Required to grant KMS permissions to the GKE service agent."
  type        = string
  # Find it with: gcloud projects describe <PROJECT_ID> --format='value(projectNumber)'
}

variable "region" {
  description = "GCP region for the cluster and all regional resources."
  type        = string
  default     = "asia-northeast1" # Tokyo — change to your preferred region
}

variable "cluster_name" {
  description = "Name of the GKE cluster."
  type        = string
  default     = "gke-prod-cluster"
}

variable "gke_master_authorized_cidr" {
  description = "CIDR block allowed to reach the GKE master API endpoint (e.g. your bastion or workstation IP)."
  type        = string
  # Example: "203.0.113.10/32"
  # To allow all: "0.0.0.0/0" (NOT recommended for production)
}

variable "node_machine_type" {
  description = "Machine type for the default node pool. e2-standard-2 is the minimum that supports kube-prometheus-stack."
  type        = string
  default     = "e2-standard-2"
}

variable "node_count" {
  description = "Number of nodes in the default node pool. Keep at 2 for cost control in demo environments."
  type        = number
  default     = 2
}

variable "kubernetes_version" {
  description = "Minimum master version for the GKE cluster. Leave empty to use the REGULAR channel default."
  type        = string
  default     = "" # Let release_channel manage the version
}
