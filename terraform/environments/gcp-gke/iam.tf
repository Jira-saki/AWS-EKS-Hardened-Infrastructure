###############################################################################
# IAM — Workload Identity for secure-api
# GCP parity to: IRSA (IAM Role for Service Accounts) on AWS EKS
#
# Chain:
#   K8s Pod (secure-api-sa) → GCP SA (secure-api-sa@<project>.iam.gserviceaccount.com)
#   → GCP IAM roles (metrics writer, trace agent, etc.)
###############################################################################

# ── GCP Service Account for the secure-api workload ──────────────────────────

resource "google_service_account" "secure_api" {
  project      = var.project_id
  account_id   = "secure-api-sa"
  display_name = "secure-api Workload Identity SA"
  description  = "GCP Service Account mapped to Kubernetes SA secure-api-sa via Workload Identity"
}

# ── Minimal GCP IAM roles for the workload ───────────────────────────────────

# Allows the workload to write custom metrics to Cloud Monitoring
resource "google_project_iam_member" "secure_api_metrics_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.secure_api.email}"
}

# Allows the workload to write traces to Cloud Trace
resource "google_project_iam_member" "secure_api_trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.secure_api.email}"
}

# ── Workload Identity Binding ─────────────────────────────────────────────────
# Allows the Kubernetes ServiceAccount (secure-api-sa in namespace "default")
# to impersonate the GCP SA above.
# GCP parity to: OIDC trust relationship in IRSA on EKS.

resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.secure_api.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    # Format: serviceAccount:<PROJECT>.svc.id.goog[<NAMESPACE>/<KSA_NAME>]
    "serviceAccount:${var.project_id}.svc.id.goog[default/secure-api-sa]",
  ]
}
