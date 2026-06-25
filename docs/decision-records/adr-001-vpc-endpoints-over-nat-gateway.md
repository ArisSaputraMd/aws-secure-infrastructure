# ADR-001 — VPC Endpoints over NAT Gateway

**Date:** 2026-05
**Status:** Accepted

---

## Context

Private subnets (ECS Fargate, RDS) need to reach AWS services — specifically ECR (image pulls), S3 (ECR layer storage), SSM Parameter Store (secrets retrieval), and CloudWatch Logs (log shipping). There are two standard options for this: a NAT Gateway or VPC Interface Endpoints.

---

## Decision

Use VPC Interface Endpoints instead of a NAT Gateway.

---

## Reasoning

| Factor          | NAT Gateway                                           | VPC Endpoints                                                                  |
| --------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------ |
| Cost            | ~$32/month minimum (hourly + data processing)         | Per-endpoint hourly rate for Interface endpoints; S3 Gateway endpoint is free  |
| Traffic routing | All outbound traffic routes via NAT to the internet   | Traffic stays within the AWS network — never hits the internet                 |
| Security        | Private subnets gain internet access as a side effect | Strict: only the specific AWS services with configured endpoints are reachable |
| Coverage        | Any internet destination                              | Only the AWS services with configured endpoints                                |

For a lab environment, the cost difference is decisive. For a production environment, the security posture is the stronger argument — traffic to ECR, S3, SSM, and CloudWatch Logs never leaves the AWS backbone.

---

## Tradeoff

Anything requiring general internet access from private subnets — for example, pulling images directly from Docker Hub — will not work without a NAT Gateway. This is addressed by routing all image pulls through ECR: images are pushed to ECR first, and the ECS task definition references the ECR URI, not Docker Hub.

---

## Services Covered

| Endpoint  | Type      | Pricing       | Purpose                    |
| --------- | --------- | ------------- | -------------------------- |
| `ecr.api` | Interface | Hourly per-AZ | ECR API calls              |
| `ecr.dkr` | Interface | Hourly per-AZ | ECR image layer pulls      |
| `s3`      | Gateway   | Free          | ECR layer storage via S3   |
| `ssm`     | Interface | Hourly per-AZ | SSM Parameter Store access |
| `logs`    | Interface | Hourly per-AZ | CloudWatch Logs shipping   |

---

## Consequences

- No NAT Gateway cost (~$32/month saved).
- Private subnets have no general internet access — acceptable given all external dependencies are on AWS services.
- Any future dependency on a non-AWS internet service from a private subnet would require adding a NAT Gateway or rearchitecting the dependency.
