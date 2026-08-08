![Build Status](https://github.com/Jira-saki/AWS-EKS-Hardened-Infrastructure/workflows/DevSecOps%20Infrastructure%20Pipeline/badge.svg)
![Terraform](https://img.shields.io/badge/Terraform-1.x-7B42BC?logo=terraform)
![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws)
![CKA](https://img.shields.io/badge/Kubernetes-CKA%20Certified-326CE5?logo=kubernetes&logoColor=white)

# AWS EKS Hardened Infrastructure (EP2)

> 🎯 **Professional Roadmap & Certification Alignment**
> - **Completed Milestone:** ✅ **CKA (Certified Kubernetes Administrator)** ➔ Certified (2026)
> - **Current Focus:** Transitioning into **AWS Certified Data Engineer – Associate (DEA)** & **AWS Certified Machine Learning (MLA)** Implementation Phase.
> - **Platform Target:** Evolving into a **Secured MLOps & Inference Platform PoC** focusing on zero-trust data access, read-only Bottlerocket nodes, and inference audit logging.

---

## Executive Summary

This repository contains a hardened, zero-trust AWS EKS baseline implemented with Terraform and validated through automated CI/CD security gates.

- Removes SSH access and public control-plane exposure
- Uses Bottlerocket managed node groups for immutable hosts
- Enforces least-privilege via OIDC + IRSA
- Uses AWS KMS CMKs for envelope encryption
- CI gates: Terraform validate, Checkov (IaC), Trivy (images/config)

---

## Hybrid Development Strategy

Two-phase validation to reduce risk and cost:

1. **Local sandbox ("Hobgoblin"):** KVM/QEMU lab for OS hardening and cloud-init validation.
2. **AWS target:** Translate validated baselines into an AWS EKS architecture (Bottlerocket, KMS, IRSA).

![Hobgoblin Local Hypervisor Topology](assets/hob-lab2.png)

---

## AWS Target Architecture & Security Pillars

- 3-tier network segmentation (public ALB/WAF, private application subnets, isolated data subnets)
- Private EKS control plane (API endpoint = Private Only)
- Bottlerocket managed node groups (no SSH, read-only root)
- AWS KMS CMKs for secrets and EBS encryption
- OIDC + IRSA for least-privilege service identities

![AWS Cloud Target Architecture](assets/AWS_SCS2.png)

---

## Security Control Matrix

| Domain | Implemented Control | Threats Addressed | Verification |
|---|---|---|---|
| Network Perimeter | 3-tier VPC + private API endpoint | Unauthorized control-plane access | Terraform spec / AWS CLI |
| Compute | Bottlerocket OS (read-only root) | Host compromise, container escape | CIS benchmarks / node spec |
| Identity & Access | IRSA (IAM roles for service accounts) | Credential leakage, over-privilege | IAM policy audit / OIDC |
| Data Protection | AWS KMS CMKs (envelope encryption) | Unencrypted secrets & volumes | KMS policy inspection |
| Supply Chain | Checkov (IaC) + Trivy (config) | Misconfigs, vulnerable dependencies | GitHub Actions pipeline |

---

## Project Structure

```text
.
├── .github/workflows/      # CI: Terraform validate, Checkov, Trivy
├── cloud-init/             # Local sandbox manifests
├── kubernetes/             # Base manifests (ingress, karpenter, observability)
├── terraform/
│   ├── environments/       # local-hob, prod
│   └── modules/            # compute, ecr, eks, network, observability, security, storage, vpc
├── assets/                 # Diagrams and topology images
└── README.md
```

---

## DevSecOps CI/CD Pipeline

```text
[ Git Push / PR ]
       │
       ▼
[ 1. Terraform Format & Validate ]
       │
       ▼
[ 2. Checkov IaC Hardening Scan ]
       │
       ▼
[ 3. Trivy Vulnerability Scan ]
       │
       ▼
┌───────────────────────────────┐
│     Security Gates Passed?    │
└───────────────────────────────┘
    │                       │
   YES                      NO
    │                       │
    ▼                       ▼
[ Approved for Merge ]    [ Block Pipeline & Alert ]
```

---

## Quick Start (Validate Only)

**Prerequisites:** `terraform >= 1.5`, AWS CLI v2 (configured), `kubectl >= 1.28`.

```bash
git clone https://github.com/Jira-saki/AWS-EKS-Hardened-infrastructure.git
cd AWS-EKS-Hardened-infrastructure/terraform/environments/prod
terraform fmt -check
terraform init -backend=false
terraform validate
```

Deploy (review plan before apply):

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

Verify cluster:

```bash
aws eks update-kubeconfig --region ap-northeast-1 --name ep2-hardened-eks
kubectl get nodes -o wide
```

Teardown:

```bash
terraform destroy -auto-approve
```

---

## Scope & MVP Status

### In-Scope (v1.0.0-production-baseline)

- 3-tier VPC with Multi-AZ NAT
- Hardened EKS cluster with private API
- AWS KMS CMKs for secrets and EBS
- IRSA (OIDC) integration
- Bottlerocket immutable node groups
- GitHub Actions pipeline (Checkov + Trivy)

### Deferred (Target for EP3 Data Platform)

- Service Mesh (Istio / Linkerd)
- Full Observability Stack (Prometheus / Grafana)
- Modern Data Ingestion & Orchestration (`dlt`, Prefect Cloud Agent on EKS)
- Distributed Data Processing (Apache Spark Operators)
- Centralized Audit Logging & SIEM Forwarding (Fluent Bit to Amazon OpenSearch)

---

## Release & Tagging

To tag and freeze this production baseline:

```bash
git add README.md
git commit -m "docs: finalize EP2 README with aligned directory structure"
git tag -a v1.0.0-production-baseline -m "EP2 MVP Production Baseline Freeze"
git push origin main --tags
```