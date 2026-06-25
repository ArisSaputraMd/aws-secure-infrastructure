# AWS Secure Infrastructure

Private-subnet Mattermost deployment on ECS Fargate — built with Terraform, secured with native AWS tooling and security controls aligned to CIS AWS Foundations Benchmark v5.0.

---

## Overview

This is a production-like deployment of Mattermost, a self-hosted team messaging platform, running on AWS ECS Fargate. The compute and database tiers run entirely in private subnets with no direct internet exposure.
AWS service access from private subnets is handled through VPC Interface Endpoints rather than a NAT Gateway — cutting ~$32/month in recurring costs while preserving network isolation.

Secrets are injected into the container at runtime via SSM Parameter Store. No credentials are baked into images or stored as plaintext environment variables.

The architecture is designed to the standards a production deployment would require — private subnet isolation, least-privilege IAM and secrets injected at runtime. Phase 2 implements the AWS Well-Architected Framework across all six pillars using native AWS services.

**Region:** `ap-southeast-3` (Jakarta)

---

## Architecture

![Architecture diagram](docs/assets/architecture-diagram.png)

```
Route 53 → ACM → ALB → ECS Fargate → RDS PostgreSQL
```

All components except the ALB run in private subnets.
See [Architecture Overview](docs/architecture/high-level-overview.md) for the full breakdown.

---

## Project Phases

| Phase   | Description                                       | Status         |
| ------- | ------------------------------------------------- | -------------- |
| Phase 1 | Core Infrastructure (VPC, ECS, RDS, ALB, Secrets) | ✅ Complete    |
| Phase 2 | AWS Well-Architected 6 Pillars                    | 🔄 In Progress |
| Phase 3 | Infrastructure Automation (Modules, CI/CD)        | 📋 Planned     |

---

## Prerequisites

- Terraform >= 1.15.5 (managed via [tfenv](https://github.com/tfutils/tfenv))
- AWS CLI configured with credentials for `ap-southeast-3`
- A registered domain in Route 53 (required for ACM certificate validation)
- An email address available to confirm SNS alert subscriptions (Phase 2)

---

## Quick Start

```bash
git clone https://github.com/ArisSaputraMd/aws-secure-infrastructure.git
cd aws-secure-infrastructure/infrastructure
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars — see the example file for required values
```

See the [Deployment Runbook](docs/runbooks/deployment-runbook.md) for the full
init, plan, apply, and destroy workflow.

> **Cost note:** This stack is designed as a deploy-and-destroy lab environment.
> Always run `terraform destroy` after each session to avoid idle charges.

---

## Documentation

| Document                                                                    | Description                                                                              |
| --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| [Architecture Overview](docs/architecture/high-level-overview.md)           | Full infrastructure breakdown — networking, compute, database, secrets, security logging |
| [Phase 1 — Core Infrastructure](docs/phases/phase-1-core-infrastructure.md) | What was built and key design decisions                                                  |
| [Phase 2 — Well-Architected](docs/phases/phase-2-well-architected.md)       | Implementation plan across the 6 pillars                                                 |
| [Phase 3 — Automation](docs/phases/phase-3-automation.md)                   | CI/CD and module extraction roadmap                                                      |
| [Deployment Runbook](docs/runbooks/deployment-runbook.md)                   | Deploy and tear down the full stack                                                      |
| [Terraform Troubleshooting](docs/runbooks/terraform-troubleshooting.md)     | Debugging workflow for common Terraform errors                                           |
| [Lessons Learned](docs/lessons-learned/index.md)                            | Real issues hit during deployment and how they were resolved                             |
| [Decision Records](docs/decision-records)                                   | Decision records and it's trade-off                                                      |

---

## Tech Stack

### Phase 1 — Core Infrastructure

| Service                   | Role                                                       |
| ------------------------- | ---------------------------------------------------------- |
| Terraform                 | Infrastructure as Code                                     |
| ECS Fargate               | Container runtime for Mattermost                           |
| RDS PostgreSQL `t3.micro` | Application database                                       |
| ALB + ACM                 | Load balancing and TLS termination                         |
| Route 53                  | DNS                                                        |
| SSM Parameter Store       | Runtime secrets injection                                  |
| VPC Interface Endpoints   | Private access to AWS APIs (ECR, S3, SSM, CloudWatch Logs) |

### Phase 2 — Security Controls (In Progress)

| Service               | Role                                        |
| --------------------- | ------------------------------------------- |
| CloudTrail + S3 + KMS | Immutable audit log, encrypted at rest      |
| EventBridge + SNS     | CIS AWS Foundations Benchmark v5.0 alerting |
| GuardDuty             | Threat detection                            |
| AWS Config            | Configuration compliance monitoring         |
| Security Hub          | Findings aggregation across services        |

---

## License

MIT — see `LICENSE`.
