# Architecture Overview

> This document covers the full architecture across all phases.
> Phase 1 components are complete. Phase 2 items are marked accordingly and will be updated as implementation progresses.

---

The diagram below shows the full request path and the relationships between infrastructure components. All application and database tier components run in private subnets with no direct internet exposure.

![Architecture diagram](../assets/architecture-diagram.png)

---

## Deployment Context

This deployment targets a medium-sized organization that prioritizes operational simplicity and cost efficiency without compromising on security posture. The platform is self-hosted to retain data control and avoid per-seat SaaS costs at scale.

Design decisions throughout this project such as compute launch type, networking approach, secrets management, state handling, etc. are made within these constraints. See the [decision records](../decision-records/) for the reasoning behind each major choice.

---

## 1. Networking

**VPC**

- IPv4 CIDR block: `10.0.0.0/16`
- Region: `ap-southeast-3` (Jakarta)
- Availability Zones: 2 AZs, dynamically selected via `slice()` based on the region's available AZs
- Internet Gateway attached
- DNS hostnames and DNS support enabled
- Tagged by environment and project name

**Subnet layout & tiering**

The VPC is segmented into a 3-tier subnet design across 2 AZs:

- Public subnets — internet-facing (ALB only)
- Private subnets — application layer (ECS Fargate)
- Private subnets — database layer (RDS)

Each subnet's CIDR block is generated automatically from the VPC CIDR using `cidrsubnet()`.

**VPC Endpoints**

Instead of a NAT Gateway, VPC Interface Endpoints handle private connectivity for ECR, S3, SSM, and CloudWatch Logs. See [ADR-001](../decision-records/adr-001-vpc-endpoints-over-nat-gateway.md) for the reasoning.

**Routing & traffic flow**

Public subnets route to the Internet Gateway. Private subnets have no direct internet route — outbound traffic to AWS services goes through VPC Endpoints instead.

**Security groups — network segmentation**

| Security Group     | Inbound                           | Outbound                                              |
| ------------------ | --------------------------------- | ----------------------------------------------------- |
| `alb-sg`           | `0.0.0.0/0` on HTTP/80, HTTPS/443 | `ecs-sg` on TCP/8065                                  |
| `ecs-sg`           | `alb-sg` on TCP/8065              | `rds-sg` on TCP/5432, `vpc-endpoints-sg` on HTTPS/443 |
| `rds-sg`           | `ecs-sg` on TCP/5432              | None                                                  |
| `vpc-endpoints-sg` | `ecs-sg` on HTTPS/443             | None                                                  |

All security group rules are defined in [networking.tf](../../infrastructure/networking.tf).

![VPC resource map console](../assets/vpc-resource-map.png)
_Figure 1: Console view of VPC resource map_

---

## 2. Route 53

DNS management for the application domain via a hosted zone, which holds records for:

- TLS certificate validation
- Application domain and subdomains
- Alias record pointing to the ALB

---

## 3. Application Load Balancer + TLS (ALB + ACM)

The ALB is deployed in the public subnets and integrated with an ACM certificate for TLS termination.

- HTTP/80 listener redirects to HTTPS/443
- HTTPS/443 listener forwards to the ECS target group
- Target group points to the ECS service on port 8065, with health checks
  over HTTP against `/api/v4/system/ping`

---

## 4. Compute (ECS Fargate)

The application runs as a Docker container in an ECS cluster using the Fargate launch type. Tasks run in private subnets with no public IP, and the security group only allows inbound traffic from `alb-sg` on port 8065.

Task definition configuration:

- `network_mode = "awsvpc"`
- `cpu = "256"`, `memory = "512"`
- Execution role: `sts:AssumeRole`, `AmazonECSTaskExecutionRolePolicy`,
  `ssm:GetParameters` scoped to the DSN parameter ARN — handles secret
  injection at container startup
- Task role: `sts:AssumeRole` — used by the running application; does not
  require SSM access
- Container definition (via `jsonencode`): pulls the image from ECR and ships
  logs to CloudWatch, both over VPC Endpoints

---

## 5. Database (RDS PostgreSQL)

RDS is deployed in the database-tier private subnets, with a security group that only allows traffic from `ecs-sg` on port 5432.

Configuration:

- PostgreSQL 16.x
- `t3.micro` instance class
- 20 GB `gp2` allocated storage
- Credentials via SSM — see [ADR-002](../decision-records/adr-002-ssm-parameter-store-over-secrets-manager.md)
- Single-AZ
- Storage encryption enabled — AWS-managed key

---

## 6. Secrets Handling

Database credentials are managed via SSM Parameter Store, not Terraform variables:

- The DB password is stored manually as a `SecureString` in SSM at `/${var.environment}/${var.project_name}/database/mattermost/password`
- A `locals` block in [ssm.tf](../../infrastructure/ssm.tf) constructs the full Postgres DSN (with `sslmode=require`) and writes it to a second SSM parameter: `/${var.environment}/${var.project_name}/database/mattermost/db_dsn`
- The ECS task definition references the DSN parameter ARN via the `secrets` block (`valueFrom`), so it is injected at container start rather than stored in plaintext environment variables
- `MM_SERVICESETTINGS_SITEURL` stays in the `environment` block since it is non-sensitive
- The ECS task execution role has `ssm:GetParameters` scoped to the DSN parameter ARN only
- See full `container_definition` in [ecs.tf](../../infrastructure/ecs.tf).

**Known limitation:** Because Terraform writes the DSN to SSM, the value also ends up in `.tfstate` in plaintext. For a local-state lab setup this is an accepted tradeoff, but it is called out here rather than glossed over.
A production setup would require a remote backend with encryption and tightly-scoped access controls — or an approach that avoids passing the DSN through Terraform entirely, such as constructing it at runtime inside the container or using Secrets Manager's native ECS integration.

See [ADR-002](../decision-records/adr-002-ssm-parameter-store-over-secrets-manager.md)
for the full reasoning.

---

## 7. Security Logging and Alerting _(Phase 2 — In Progress)_

> The components in this section are part of Phase 2 and are being implemented incrementally. This section reflects the target state, not the current deployed state.

Management events are captured across all regions via CloudTrail and delivered to S3 as the single store for both long-term retention and forensic investigation. EventBridge routes specific event patterns to SNS for alerting. Athena queries S3 directly for ad-hoc investigation.

**S3 log bucket design**

| Property      | Value                                                                                            |
| ------------- | ------------------------------------------------------------------------------------------------ |
| Encryption    | SSE-KMS with CMK (`bucket_key_enabled = true` to reduce per-object KMS API call cost)            |
| Public access | Fully blocked at bucket level                                                                    |
| Object lock   | COMPLIANCE mode, 365 days — logs cannot be deleted or overwritten, including by the root account |
| Versioning    | Enabled (required for object lock)                                                               |
| Lifecycle     | STANDARD → STANDARD_IA (day 30) → GLACIER_IR (day 90) → DEEP_ARCHIVE (day 365)                   |

The lifecycle policy moves logs through cheaper storage tiers as they age without expiring them before the object lock period ends.

**KMS (Customer-Managed Key)**

A dedicated CMK encrypts the S3 bucket. Using a CMK over the AWS-managed default gives key rotation control and fine-grained policy scoping — CloudTrail can only use the key for its own trail ARNs via encryption context conditions.

**Bucket policy scoping**

Both `GetBucketAcl` and `PutObject` grants to the CloudTrail service principal are conditioned on `aws:SourceArn`, scoping delivery to this specific trail only.

**Alerting**

EventBridge rules match specific CloudTrail event patterns and route to SNS for notification. Controls are aligned to CIS AWS Foundations Benchmark v5.0, covering:

| Control       | Event                            |
| ------------- | -------------------------------- |
| CIS 1.7       | Root account usage               |
| CIS 1.10      | Console login without MFA        |
| CIS 3.5       | CloudTrail configuration changes |
| CIS 3.7       | KMS key deletion or disablement  |
| CIS 4.4 / 4.6 | IAM privilege escalation         |
| CIS 4.11      | Network ACL changes              |
| CIS 5.3       | Security group changes           |

**Investigation**

Athena queries S3 directly using the CloudTrail table schema. Ad-hoc, pay-per-query — no infrastructure to maintain.
