# AWS Secure Infrastructure

A production-grade, highly available, and enterprise-hardened cloud architecture deployed on AWS using Terraform. This repository hosts a zero-trust network infrastructure designed to host containerized mission-critical applications (using a Mattermost Enterprise Collaboration container as the primary validation stack) while maintaining an rigorous security posture and a cost-optimized footprint (FinOps).

This repository serves as a multi-phase cloud security portfolio:

- Phase 1: Secure Core Infrastructure & Network Topology (`Current`).

- Phase 2: Observability, SIEM Integration & Threat Detection (`In Progress`).

- Phase 3: Incident Response Playbooks & Threat Hunting (`Planned`).

- Phase 4: Automated Security Remediation via AWS Lambda (`Planned`).

---

## Architecture Diagram

_Diagram will be added here when Phase 1 is complete._

---

## Tech Stack

| Service         | Purpose                         | Why this over the alternative                                                                                                                        |
| --------------- | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Terraform       | Infrastructure as Code          | Reproducible, version-controlled infrastructure; destroy and redeploy in minutes                                                                     |
| ECS Fargate     | Run Mattermost container        | No cluster management vs EKS; cheaper and simpler for single-app deployment                                                                          |
| RDS PostgreSQL  | Back-end Datastore              | Configured for relational data storage with encrypted storage-at-rest. Free-tier compliant for staging.; Aurora Serverless costs ~$0.06/hr even idle |
| ALB             | Load balancer + TLS termination | Integrates natively with ACM and ECS; handles HTTPS offloading                                                                                       |
| ACM             | TLS certificate                 | Free, auto-renews, integrates with ALB and CloudFront                                                                                                |
| CloudFront + S3 | CDN + static/error pages        | Reduces origin load; serves custom error pages without hitting ECS                                                                                   |
| Route 53        | DNS management                  | Native AWS integration with ALB and CloudFront; supports health checks                                                                               |
| VPC Endpoints   | Private AWS service access      | Eliminates NAT Gateway cost for ECR, S3, and CloudWatch Logs (~$0.15–0.30/session saved)                                                             |

---

## Key Technical & FinOps Decisions

- **ECS Fargate over EKS** — Kubernetes adds operational overhead that is not justified for a single application. Fargate removes server management entirely.
- **RDS PostgreSQL over Aurora Serverless v2** — Aurora is not free tier eligible and costs money even when idle. RDS t3.micro is free for 12 months.
- **VPC Endpoints over NAT Gateway** — NAT Gateway costs ~$0.045/hr plus data transfer fees. VPC Endpoints for ECR, S3, and CloudWatch Logs eliminate this cost for private subnet resources.
- **Single-AZ RDS for Phase 1** — Multi-AZ doubles RDS cost with no benefit in a lab environment.
- **ACM over self-signed certificates** — Free, trusted by all browsers, auto-renews, zero operational overhead.
- **Parameterized Multi-Environment Code**: The entire codebase utilizes highly structured Terraform variables (variables.tf). While active development runs on a single Availability Zone utilizing db.t3.micro to stay inside the AWS Free Tier, flipping the environment variable to "prod" instantly scales the infrastructure to a Multi-AZ, high-availability cluster.

---

## Infrastructure Breakdown

### Networking

_To be completed when Phase 1 Terraform is deployed._

### Compute (ECS Fargate)

_To be completed when Phase 1 Terraform is deployed._

### Database (RDS PostgreSQL)

_To be completed when Phase 1 Terraform is deployed._

### Load Balancer + TLS (ALB + ACM)

_To be completed when Phase 1 Terraform is deployed._

### CDN + Static Files (CloudFront + S3)

_To be completed when Phase 1 Terraform is deployed._

### DNS (Route 53)

_To be completed when Phase 1 Terraform is deployed._

---

## Infrastructure Code Layout

The project follows standard HashiCorp structural conventions to maintain modularity and visibility for technical review:

```
aws-secure-infrastructure/
├── README.md
├── .gitignore
├── terraform/
   ├── main.tf
   ├── providers.tf
   ├── versions.tf
   ├── variables.tf
   ├── terraform.tfvars.example
   ├── outputs.tf
   ├── networking.tf
   ├── security.tf
   ├── iam.tf
   ├── alb.tf
   ├── ecs.tf
   ├── rds.tf
   ├── acm.tf
   ├── cloudfront.tf
   ├── s3.tf
   └── dns.tf

```

---

## How to Safely Deploy (FinOps Lifecycle)

This project utilizes a State Cycle Strategy to develop enterprise infrastructure without generating running idle costs. To deploy the stack locally:

### 1. Prerequisites

- `AWS CLI` installed and authenticated (`aws configure`).
- `tfenv` installed via Homebrew
  ```
  $ brew install tfenv
  $ tfenv install 1.15.5
  $ tfenv use 1.15.5
  ```

### 2. Execution Setup

- Clone the repository and initialize the project:
  ```
  $ git clone https://github.com/ArisSaputraMd/aws-secure-infrastructure.git
  $ cd aws-secure-infrastructure
  ```
- Create your localized configuration variables file by copying the example template:
  ```
  $ cp terraform.tfvars.example terraform.tfvars
  ```
  _Modify `terraform.tfvars` with your specific local parameters (this file is automatically blocked by `.gitignore`)._

### 3. Apply the Infrastructure

- Initialize the working directory and execute the plan:
  ```
  $ terraform init
  $ terraform plan -out=tfplan
  $ terraform apply tfplan
  ```

### 4. Tear-Down (Cost Mitigation Routine)

When testing or code reviews are complete, completely purge the running resources to bring the billing rate back to zero:

```
$ terraform destroy -auto-approve
```

---

## Infrastructure Cost Analysis

To demonstrate production feasibility while keeping development overhead zero, the lifecycle cost of running a single validation session is broken down below:

| Resource Type | AWS Component             | Cost per 4-Hour Dev Session  | Live Production Cost (Monthly Scale) |
| ------------- | ------------------------- | ---------------------------- | ------------------------------------ |
| Database      | RDS db.t3.micro           | $0.00 (Free Tier)            | ~$34.00 (Multi-AZ Production)        |
| Compute       | ECS Fargate Tasks         | ~$0.04                       | ~$22.00 (2x Tasks Scaled)            |
| Networking    | Application Load Balancer | ~$0.09                       | ~$16.24                              |
| Endpoints     | Interface VPC Endpoints   | ~$0.04                       | ~$21.60                              |
| Edge Cache    | CloudFront & S3           | $0.00 (Free Tier Allocation) | Variable by Traffic Volume           |
|               |                           | Total Session Cost~$0.17     | Ready for Enterprise Pivot           |

---

## Roadmap

- [ ] **Phase 1 — Core Infrastructure** — VPC, ECS Fargate, RDS, ALB, CloudFront, Route 53, Terraform
- [ ] **Phase 2 — Observability & Threat Detection** — CloudWatch dashboards, WAF, GuardDuty, VPC Flow Logs, CloudTrail
- [ ] **Phase 3 — Incident Response Runbooks** — 3 documented security scenarios investigated using Phase 2 tooling
- [ ] **Phase 4 — Security Automation** — GuardDuty → EventBridge → Lambda auto-remediation

---

## What I Learned

_To be completed after Phase 1 is deployed. Will cover real problems encountered and how they were solved._

---

## License

Distributed under the MIT License. See LICENSE for more information.
