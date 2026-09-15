###############################################################################
# Cloud KMS — etcd Database Encryption (CMEK)
# GCP parity to: AWS KMS envelope encryption on EKS secrets
###############################################################################

resource "google_kms_key_ring" "gke" {
  project  = var.project_id
  name     = "${var.cluster_name}-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "gke_etcd" {
  name            = "${var.cluster_name}-etcd-key"
  key_ring        = google_kms_key_ring.gke.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s" # 90 days

  lifecycle {
    # Prevent accidental deletion — a destroyed key makes the cluster unrecoverable
    prevent_destroy = true
  }
}

###############################################################################
# IAM — Grant the GKE service agent permission to use the KMS key
#
# The GKE service agent identity follows this pattern:
#   service-<PROJECT_NUMBER>@container-engine-robot.iam.gserviceaccount.com
###############################################################################

resource "google_kms_crypto_key_iam_binding" "gke_etcd_encrypter" {
  crypto_key_id = google_kms_crypto_key.gke_etcd.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:service-${var.project_number}@container-engine-robot.iam.gserviceaccount.com",
  ]
}
