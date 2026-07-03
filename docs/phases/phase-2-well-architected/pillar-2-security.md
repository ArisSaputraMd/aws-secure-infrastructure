# Security Pillar

**Status:** Completed | `dev` environment | deploy-and-destroy lab model

---

## Security Posture

![security posture](../../assets/img)

### Detection

**1. AI based detection threat - GuardDuty**
GuardDuty use CloudTrail logs, VPC Flow Logs and DNS query logs to detect threat via machine learning. The findings then pulled and agregated with another security sevice findings by SecurityHub.

**2. Automated compliance checks — AWS Security Hub**
Security Hub continuously evaluates two standards `CIS AWS Foundations Benchmark v5.0.0` and `AWS Foundational Security Best Practices (FSBP)` and agregate security/compliance findings from GuardDuty, AWS Inspector, IAM access analyzer and AWS Config.

A single EventBridge rule filters findings from _either_ standard at
`HIGH`/`CRITICAL` severity and `Workflow.Status = NEW`, pushing them to SNS.

**3. Event based detection — EventBridge + CloudTrail**
Though SecurityHub can cover most of the security consern, it required multiple step to finally detected. To add real-time alert it require a purpose built detection mechanism. These EventBridge rules filter CloudTrail management events directly and serve as that mechanism.

| Rule                      | Trigger Events                                                                                                            | Why it matters                                                                                       |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Root account usage        | Any API call by root                                                                                                      | Root has unrestricted access, day-to-day ops should never touch it                                   |
| IAM privilege escalation  | `CreateUser`, `AttachUserPolicy`, `PutRolePolicy`, `AttachRolePolicy`, `PassRole`, `UpdateAssumeRolePolicy`               | `PassRole` is especially high-signal, it lets one principal delegate a role's permissions to another |
| CloudTrail config changes | `StopLogging`, `DeleteTrail`, `UpdateTrail`, `PutEventSelectors`, `PutInsightSelectors`                                   | Disabling CloudTrail is a common technique to erase the audit trail before/during a breach           |
| Security group changes    | `AuthorizeSecurityGroupIngress/Egress`, `RevokeSecurityGroupIngress/Egress`, `CreateSecurityGroup`, `DeleteSecurityGroup` | Most common path to accidentally exposing ECS/RDS to the internet                                    |
| Console login without MFA | Successful `ConsoleLogin` with `MFAUsed=No`                                                                               | Flags credential hygiene failures                                                                    |
| KMS key deletion/disable  | `DisableKey`, `ScheduleKeyDeletion`                                                                                       | `ScheduleKeyDeletion` has a 7–30 day window to cancel before data is unrecoverable                   |
| NACL changes              | `Create/DeleteNetworkAcl(Entry)`, `ReplaceNetworkAclEntry/Association`                                                    | Stateless layer that can silently bypass SG-level controls                                           |

### Identity & access management

This project is deployed in a single AWS account to simplify deployment and control costs. In a production enterprise environment, the architecture would typically be extended to a multi-account structure using AWS Organizations with dedicated management, security, logging, development, and production accounts.

Root account are using MFA, and day-to-day Ops are using IAM user with least-privilage permission. Users are not attched to a policy, instead it nested uder group policy. ECS task and other services are using role with limited permission.

IAM Access Analyzer are enabled detects unintended external access to resources and AWS Config rule are managed by SecurityHub to automatically check compliance and detect configuration drift.

### Infrastructure protection

AWS WAF

Traffic that use unsecured protocol (http/80) are redirected to https/443 and ALB will terminate the TLS connection in public subnet.

Resources are place inside private subnet with no outbound allowed except trough VPC endpoints. The network inside VPC are segmented by Security Groups with strict rule.

| Security Group     | Inbound                           | Outbound                                                                   |
| ------------------ | --------------------------------- | -------------------------------------------------------------------------- |
| `alb-sg`           | `0.0.0.0/0` on HTTP/80, HTTPS/443 | `ecs-sg` on TCP/8065                                                       |
| `ecs-sg`           | `alb-sg` on TCP/8065              | `rds-sg` on TCP/5432, `vpc-endpoints-sg` on HTTPS/443, S3 Gateway Endpoint |
| `rds-sg`           | `ecs-sg` on TCP/5432              | None                                                                       |
| `vpc-endpoints-sg` | `ecs-sg` on HTTPS/443             | None                                                                       |

### Data protection

Database are placed inside private subnet with security group that only allow inbound from ECS security group. The database credential's are saved in SSM SecureString.

RDS postgress database are encryption with KMS CMK with key rotation in every 90 days and API calls to S3 are restricted to SSL connection only. This set-up ensure data are protected both in rest and transit.

### Application security

Docker container runs as a non-root user(UID 0). Instead, it runs as a regular, unprivileged user.

ECR are configured with scan-on-push with enhence scaning and continuous scaning by AWS Inspector. AWS inspector will rescanning due to newly disclosed vulnerabilities (CVE).

### Incident response

This runbook defines the process for preparation, detecting, investigating, containing, eradicating, and recovering from security incidents affecting the AWS environment. It ensures incidents are handled consistently while minimizing business impact.

**1. Preparation**

Preparation include activities such as:

- Vulnerability Scan (AWS Inspector)
- Security Hardening (Explicit ACL's, SG's, VPC Endpoint's, IAM, etc)
- Tunning the preventive and detection tools (WAF, AWS Configs rules, EventBridge rules, etc.) based on lesson learned.
- Threat haunting (Kill Chain / ATT&CK Campaign Simulation)
- Modify or update Incident response runbook.

**2. Detection**

Detection Source :

- GuardDuty findings
- Security Hub findings
- AWS Config compliance violations
- CloudWatch alarms
- CloudTrail events
- WAF blocked requests

Trigger - Incident begins when one of the following occurs:

- High or Critical GuardDuty finding
- Security Hub High/Critical finding
- CloudWatch alarm
- AWS Config rule becomes NON_COMPLIANT
- Suspicious CloudTrail activity

Initial Actions

- Determine severity
- Record the details (IP addresses, detection time, affected resource, AWS Account ID, Finding ID, ect.)

**3. Triage**

Prioritize which alerts are worth investigating (severity), determine if the alert is genuine, False positive, Which resources are affected, Current impact and Possible attacker activity.

**4. Investigation**

Collect Evidence (artifact), agregate and review context of history loggs (securityhub/athena) and implement MITRE AT&CK framework to check the possibility of common attacks (Tactics, Technique, and Procedures)

**5. Containment**

Isolate the affected resources (restrict ACL/SG's access, block attacker IP using WAF, etc), Disable compromised user, Remove access keys, Stop compromised task, etc.

**6. Eradication**

Remove the root cause, examples:

- Patch vulnerable application
- Remove malicious container image
- Update IAM policies
- Remove unused access keys
- Enable MFA
- Delete unauthorized resources

**7. Recovery**

Restore production and Monitor environment for 24–48 hours. Verify:

- ECS healthy
- ALB healthy
- Mattermost accessible
- No active GuardDuty findings
- Security Hub findings resolved
- Config resources compliant
- CloudWatch alarms cleared

**8. Lesson Learn**

Conduct a post incident review and Documenting the timeline, root cause, detection source, impact, response actions, recovery time, preventive actions and update incident response runbook.

## Components delivered

| Component                      | Decision rationale                                                                                                                           |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| VPC Flow Logs                  | Send logs to CloudWatch logs group, capture metadata of all traffic type IP's                                                                |
| AWS Config                     | CONTINUOUS, all resource types, shared security_logs S3 bucket, KMS CMK                                                                      |
| AWS GuardDuty                  | Consume metadata from VPC Flow Logs, Detect anomaly and threat                                                                               |
| AWS SecurityHub                | Classic CSPM + SecurityHub v2, foundational-security-best-practices/v/1.0.0, cis-aws-foundations-benchmark/v/5.0.0, product/aws/guardduty    |
| CloudTrail + S3 (`logs`) + KMS | Multi-region management event capture; S3 with COMPLIANCE object lock, SSE-KMS with CMK, lifecycle tiering to IA → Glacier IR → Deep Archive |
| EventBridge + SNS              | Capture violated CloudTrail event against CIS Benchmark V5.0, route to SNS Topics for notification                                           |

```note
GuardDuty and Security Hub deferred due to AWS Business Support tier requirement on free-tier accounts, to be enabled when upgraded
```

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

### Explicitly deferred

| Item                                                      | Deferred to                                     | Reason                                                                                                             |
| --------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Multi-AZ RDS                                              | Phase 2 — Reliability pillar                    | Doubles RDS cost; no real benefit in a lab environment                                                             |
| Remote Terraform state (S3 backend + DynamoDB lock table) | Phase 3                                         | Low-effort, no downside — but not needed until CI/CD is introduced; identified as a hard blocker for Phase 3       |
| Secrets Manager                                           | Phase 2 — Security pillar (under consideration) | SSM `SecureString` covers Phase 1 requirements; Secrets Manager migration not yet confirmed for Phase 2 scope      |
| Terraform modules                                         | Phase 3                                         | Module boundaries are not yet clear; premature extraction before Phase 2 is complete introduces wrong abstractions |
| WAF                                                       | Open — requires explicit in/out decision        | Introduces an ongoing cost line item; deliberate scoping decision required before Phase 2 begins                   |

---

## Validation

Infrastructure was validated before Phase 1 was marked complete:

- `terraform validate` passes

![terraform validation](../assets/terraform-success-validation.png)

- `terraform plan` completes with no errors and no unexpected diffs

![terraform plan](../assets/terraform-plan-p1.png)

- `terraform apply` completed

![terraform apply](../assets/terraform-apply-p1.png)

- VPC resource map

![VPC resource map console](../assets/vpc-resource-map.png)

- ECS service healthy

![ECS task console](../assets/ecs-service-health.png)

- ECS task reaches `RUNNING` state and connects to RDS successfully

![ecs task running](../assets/ecs-task-running-p1.png)

- RDS Connect to VPC EndPoint interface

![rds](../assets/rds-connectivity-and-security.png)

- Mattermost loads over HTTPS

![mattermost.aris-saputra.dev screenshot](../assets/mattermost.aris-saputra.dev-website.png)

- Uploaded file stored into S3 bucket

![file in s3](../assets/mattermost-file-in-s3-storage.png)

- CloudTrail logs delivered to S3 security logs

![security logs bucket](../assets/security-logs-bucket.png)

- S3 bucket object lock compliance mode denied deleting bucket

![s3 log bucket delete denied](../assets/delete-s3-bucket-denied.png)

- `terraform destroy` passes

![terraform destroy](../assets/tf-destroyed.png)

> The domain is not permanently live. The stack uses a deploy-and-destroy model — it is spun up during active lab sessions and torn down afterward to control cost. The screenshot above is the validation artifact.

---

## Accepted Tradeoffs

| Tradeoff                                 | Accepted because                                                                                                                                                                                                                                                 |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Single-AZ RDS                            | Multi-AZ doubles cost with no real benefit in a lab environment. Upgrade scoped to Phase 2 Reliability pillar.                                                                                                                                                   |
| Local Terraform state                    | `.tfstate` stores the DSN in plaintext as a side effect of Terraform managing the SSM parameter. Acceptable for a local-state lab; production requires a remote backend with encryption and scoped access controls. Remote state migration is scoped to Phase 3. |
| SSM Parameter Store over Secrets Manager | `SecureString` is free on the standard tier. See [ADR-002](../decision-records/adr-002-ssm-parameter-store-over-secrets-manager.md).                                                                                                                             |
| DSN constructed and written by Terraform | Avoids runtime complexity in Phase 1. The consequence — DSN ending up in `.tfstate` in plaintext — is documented above and in the [architecture overview](../architecture/overview.md).                                                                          |

---

## Issues Encountered

Real debugging issues hit during Phase 1 — ECS role confusion, URI encoding in the DSN, and Terraform security group dependency cycles — are documented in [Lessons Learned](../lessons-learned/index.md).

---

## Next Phase

[Phase 2 — AWS Well-Architected 6 Pillars →](phase-2-well-architected.md)
