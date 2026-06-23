![CI/CD](https://img.shields.io/github/actions/workflow/status/Jira-saki/AWS-EKS-Hardened-infrastructure/ci.yml?label=CI%2FCD&logo=githubactions) ![Terraform](https://img.shields.io/badge/Terraform-1.x-7B42BC?logo=terraform) ![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws)

# AWS EKS Hardened Infrastructure (EP2)
> 🎯 **Professional Roadmap & Certification Alignment**
> - **Current Milestone:** Actively prepping for **CKA (Certified Kubernetes Administrator)** ➔ Exam scheduled for **MID June, 2026**.
> - **Next Milestone (Post-CKA):** Transitioning directly into **AWS Certified Security - Specialty (SCS)** Implementation Phase.

## Summary

This repo demonstrates the design and prototyping of a hardened AWS EKS modernization platform for migrating 14 legacy sites from insecure shared hosting to immutable infrastructure.

- Architecture built for security, isolation, and operational visibility
- Local first: validated tooling and hardening in a private KVM/QEMU lab ("Hobgoblin") before cloud rollout
- Cloud ready: AWS EKS with Bottlerocket nodes, IRSA, strict VPC segmentation, and SIEM-style observability

## What this demonstrates

- End-to-end infrastructure design and implementation with Terraform
- Host hardening and secure local prototyping before production deployment
- Deployable security controls for legacy web workloads on AWS
- Observability and threat detection integration for operational readiness

## Role

Lead architect and implementer: Responded to a production security breach [EP1](https://github.com/Jira-saki/The-Walking_Dead-22-Domains) by designing a hardened AWS infrastructure platform. Built and validated a hybrid local-to-cloud workflow, created modular Terraform infrastructure-as-code, and successfully secured the migration of 14 legacy domains to isolated, immutable infrastructure.

## Background

This platform responds to [EP1](https://github.com/Jira-saki/The-Walking_Dead-22-Domains), a compromise of legacy domains on shared hosting caused by poor isolation and unmonitored lateral movement.

- Previous issues: manual SSH access, shared kernels, weak tenant separation
- EP2 objective: eliminate shared trust boundaries and enforce immutable, least-privilege infrastructure

## Project Structure

```text
📂 AWS-EKS-Hardened-infrastructure
├── 📂 terraform
│   ├── 📂 environments
│   │   ├── 📂 local-hob
│   │   └── 📂 aws-eks
│   └── 📂 modules
│       ├── 📂 network
│       └── 📂 compute
│
├── 📂 gitops                         # GitOps Directory (Argo CD Control Plane)
│   └── 📂 platform-services          # Platform operators deployed via Argo CD
│       └── monitoring.yaml           # Argo CD Application for Prometheus & Grafana
│
├── 📂 cloud-init
├── 📂 scripts
├── 📂 assets
└── README.md
