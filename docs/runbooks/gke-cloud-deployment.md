================================================================================
  RUNBOOK: GCP GKE Hardened Infrastructure - Deployment & Teardown
  Step-by-Step Checklist with Evidence Capture (Proof-of-Work)
================================================================================
Last Updated : 2026-09-15
Purpose      : Cloud Deployment Guide + Portfolio Evidence Collection
Cloud Parity : GCP GKE (this file) <---> AWS EKS (eks-cloud-deployment.md)

  GCP Parity Mapping:
    Feature           AWS EKS                        GCP GKE (this)
    ─────────────────────────────────────────────────────────────────────────
    Node OS           Bottlerocket                   COS_CONTAINERD + Shielded
    Secrets Enc.      KMS envelope (EKS)             Cloud KMS CMEK (etcd)
    Pod Identity      IRSA                           Workload Identity
    Ingress / LB      AWS ALB Controller             GKE Gateway API + NEGs
    Node Autoscaling  Karpenter                      GKE Cluster Autoscaler


================================================================================
  Phase 1: Pre-Flight & GCP Authentication
================================================================================

[ ] 1.1  Verify gcloud CLI Authentication and Active Project
         $ gcloud auth login
         $ gcloud config set project <PROJECT_ID>
         $ gcloud config set compute/region <REGION>
         $ gcloud iam service-accounts list   # sanity-check project access


[ ] 1.2  Enable Required GCP APIs (one-time, idempotent)
         $ gcloud services enable \
             container.googleapis.com \
             cloudkms.googleapis.com \
             compute.googleapis.com \
             iam.googleapis.com \
             monitoring.googleapis.com \
             cloudtrace.googleapis.com


[ ] 1.3  Populate Terraform Variables
         # Edit terraform/environments/gcp-gke/variables.tf (or create a .tfvars):
         $ cat > terraform/environments/gcp-gke/terraform.tfvars << EOF
         project_id                 = "<YOUR_PROJECT_ID>"
         project_number             = "<YOUR_PROJECT_NUMBER>"
         region                     = "<YOUR_REGION>"
         gke_master_authorized_cidr = "<YOUR_WORKSTATION_CIDR>/32"
         EOF

         # Retrieve project number automatically:
         $ gcloud projects describe <PROJECT_ID> --format='value(projectNumber)'


[ ] 1.4  Run Terraform to Provision Infrastructure
         $ cd terraform/environments/gcp-gke
         $ terraform init
         $ terraform plan -out=tfplan
         $ terraform apply tfplan


[ ] SCREENSHOT #1 - Terraform Apply Complete
         Capture terminal showing:
           Apply complete! Resources: XX added, 0 changed, 0 destroyed.
         And Outputs table showing:
           cluster_name, cluster_endpoint, workload_identity_pool,
           kms_key_id, secure_api_gsa_email


================================================================================
  Phase 2: Cluster Connectivity & Shielded COS Node Verification
================================================================================

[ ] 2.1  Authenticate kubectl Against the New GKE Cluster
         $ gcloud container clusters get-credentials <CLUSTER_NAME> \
             --region <REGION> \
             --project <PROJECT_ID>


[ ] 2.2  Verify Control Plane and Nodes Status
         $ kubectl get nodes -o wide


[ ] 2.3  Verify Shielded Node & COS OS details
         $ kubectl get nodes -o json | jq '.items[].status.nodeInfo | {os: .operatingSystem, osImage: .osImage, kubelet: .kubeletVersion}'


[ ] SCREENSHOT #2 - Shielded COS Node Verification
         Capture output of `kubectl get nodes -o wide`
         Confirm OS-IMAGE column shows "Container-Optimized OS" (cos)
         All nodes must show status "Ready"
         The jq output confirms os: "linux" and osImage containing "cos"


================================================================================
  Phase 3: Workload & GKE Gateway API (Prod Overlay)
================================================================================

[ ] 3.0  Verify Gateway API CRDs are Installed (GKE 1.24+)
         $ kubectl get crd gateways.gateway.networking.k8s.io
         $ kubectl get gatewayclass gke-l7-global-external-managed


[ ] 3.1  Update ServiceAccount Annotation in Overlay
         # Replace <PROJECT_ID> in kubernetes/apps/overlays/gcp-prod/serviceaccount.yaml
         $ sed -i 's/<PROJECT_ID>/<YOUR_ACTUAL_PROJECT_ID>/g' \
             kubernetes/apps/overlays/gcp-prod/serviceaccount.yaml


[ ] 3.2  Deploy Production Overlay via Kustomize
         $ kubectl apply -k kubernetes/apps/overlays/gcp-prod/


[ ] 3.3  Verify Pods, Services, HPA, and Gateway
         $ kubectl get pods,svc,gateway,httproute,hpa -n default -o wide

         NOTE: Wait 3-5 minutes for the GCP Cloud Load Balancer to provision.
               Gateway ADDRESS will show a public IP (e.g. 34.x.x.x) when ready.
               Use: kubectl get gateway secure-api-gateway -w


[ ] SCREENSHOT #3 - Production Gateway & Pods
         Capture terminal showing:
           - Pod "secure-api" in 1/1 Running state, all replicas running
           - Gateway "secure-api-gateway" with ADDRESS column populated (public IP)
           - HTTPRoute "secure-api-route" status ACCEPTED


================================================================================
  Phase 4: Observability, Metrics & Alert Pipeline
================================================================================

[ ] 4.0  Deploy Observability Stack (kube-prometheus-stack) & PrometheusRules
         $ kubectl apply -k kubernetes/observability/
         $ kubectl get pods -n monitoring

         NOTE: Wait for all monitoring pods to reach Running/Ready state.


[ ] 4.1  Send Test Traffic via Public Gateway IP
         $ GATEWAY_IP=$(kubectl get gateway secure-api-gateway -n default \
             -o jsonpath='{.status.addresses[0].value}')
         $ curl -I http://$GATEWAY_IP/healthz
         $ curl -sI http://$GATEWAY_IP/


[ ] 4.2  Verify Prometheus Scrape Target (up == 1)
         $ kubectl -n monitoring port-forward \
             svc/$(kubectl get svc -n monitoring \
               -l app=kube-prometheus-stack-prometheus \
               -o jsonpath='{.items[0].metadata.name}') 9090:9090 &
         $ curl -sG \
             --data-urlencode 'query=up{service="secure-api-svc"}' \
             http://localhost:9090/api/v1/query | jq .data.result


[ ] 4.3  Verify Recording Rules via Prometheus
         $ curl -sG \
             --data-urlencode 'query=job:http_requests_total:rate5m' \
             http://localhost:9090/api/v1/query | jq .data.result


[ ] SCREENSHOT #4 - End-to-End Observability
         Capture Prometheus Web UI or Terminal jq output showing:
           query result: job:http_requests_total:rate5m
           Target on GCP cloud with status UP
           (open Prometheus UI at http://localhost:9090/targets)


================================================================================
  Phase 5: Workload Identity Verification (Bonus)
================================================================================

[ ] 5.1  Verify Workload Identity is Active on Pod
         $ kubectl exec -it deploy/secure-api -- \
             curl -s -H "Metadata-Flavor: Google" \
             "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email"

         Expected output: secure-api-sa@<PROJECT_ID>.iam.gserviceaccount.com
         (confirms the Pod is using the GCP SA, not the node SA)


================================================================================
  Phase 6: Clean Teardown & Cost Elimination (Destroy)
================================================================================

  [!!! WARNING - SRE BEST PRACTICE - READ BEFORE PROCEEDING !!!]

      On GKE, running `terraform destroy` while GKE-managed cloud resources
      still exist will leave ORPHANED resources that incur ongoing cost and
      block VPC/subnet deletion. Always delete in this order:

        1. Workloads + Gateway/HTTPRoute  → deprovisions Cloud Load Balancer
        2. PVCs (all namespaces)          → deprovisions Persistent Disks
        3. Confirm LB and PDs are gone   → verify in gcloud CLI
        4. Kill port-forwards
        5. terraform destroy

      The KMS CryptoKey has `lifecycle { prevent_destroy = true }`.
      You must remove that block and re-apply BEFORE destroy if you want
      to delete the key ring as well. Alternatively, schedule key deletion
      manually: gcloud kms keys versions destroy ...


[ ] 6.1  Delete Workloads and Gateway (Deprovisions Cloud Load Balancer)
         $ kubectl delete -k kubernetes/apps/overlays/gcp-prod/
         $ kubectl delete -k kubernetes/observability/


[ ] 6.2  Release all Persistent Disks by Deleting PVCs Across All Namespaces
         $ kubectl delete pvc --all -A

         # Confirm all GCP Persistent Disks are released (status: READY -> not attached):
         $ gcloud compute disks list \
             --filter="labels.kubernetes_io_created_for_pvc_name:*" \
             --format="table(name,status,sizeGb,zone)"

         NOTE: Wait until no disks remain in "READY" state before proceeding.


[ ] 6.3  Confirm Cloud Load Balancer has been Deprovisioned
         $ gcloud compute forwarding-rules list \
             --filter="description~secure-api" \
             --format="table(name,IPAddress,target)"

         NOTE: Output must be empty before running terraform destroy.


[ ] 6.4  Kill Any Remaining Port-Forward Processes
         $ pkill -f "port-forward"


[ ] 6.5  Destroy All Infrastructure via Terraform
         $ cd terraform/environments/gcp-gke
         $ terraform destroy --auto-approve


[ ] SCREENSHOT #5 - Complete Teardown
         Capture final terminal line showing:
           Destroy complete! Resources: XX destroyed.
         Confirms no resources remain and cost is zero.


[ ] 6.6  (Optional) Verify in GCP Console
         $ gcloud container clusters list --filter="name=<CLUSTER_NAME>"
         $ gcloud compute networks list --filter="name~<CLUSTER_NAME>"

         Both commands should return empty results.


================================================================================
  Evidence Summary Table
================================================================================

  IMG  Description                                       Verification Purpose
  ---  ────────────────────────────────────────────────  ──────────────────────────────────────────
  01   Terminal: terraform apply complete                Verify IaC automation on GCP
  02   Terminal: kubectl get nodes -o wide + jq osImage  Verify COS + Shielded Nodes on GKE
  03   Terminal: kubectl get gateway,pods                Verify GKE Gateway API & Pods ready
  04   Prometheus UI or API: PromQL rate5m               Verify Full-stack Observability on GCP
  05   Terminal: terraform destroy complete              Verify Clean Teardown & Lifecycle


================================================================================
  Quick Reference: Key Differences from EKS Runbook
================================================================================

  Aspect              AWS EKS                        GCP GKE
  ──────────────────  ─────────────────────────────  ───────────────────────────────────────
  Auth CLI            aws sts get-caller-identity    gcloud auth login
  Kubeconfig          aws eks update-kubeconfig      gcloud container clusters get-credentials
  Node OS check       kubectl get nodes -o wide      kubectl get nodes -o wide + jq osImage
  Ingress resource    Ingress (ALB annotation)       Gateway + HTTPRoute (Gateway API)
  LB address field    ingress.status.ADDRESS         gateway.status.addresses[0].value
  LB cleanup verify   aws elbv2 describe-lb...       gcloud compute forwarding-rules list
  Disk cleanup        kubectl delete pvc + aws ec2   kubectl delete pvc + gcloud compute disks


================================================================================
  END OF RUNBOOK
================================================================================
