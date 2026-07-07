# Security Pillar

**Status:** in progress | `dev` environment | deploy-and-destroy lab model

---

## Scope

This document covers the Security pillar only. Operational monitoring for ECS and RDS (application/database logs, health metrics, CloudWatch Alarms for service availability) is covered separately under the Operational Excellence pillar.

Security logging (CloudTrail, VPC Flow Logs, ALB access logs, WAF logs) and operational logging are intentionally split. See Detection #6. for the reasoning.

---

## Threat Model

Before listing controls, it's worth stating what they're defending against:

| Threat                                              | Primary control(s)                                                                                          |
| --------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Credential stuffing / brute force on login          | WAF login-rate-limit, MFA on root                                                                           |
| Injection attacks (SQLi, known CVE payloads)        | WAF managed rule groups (SQLi, KnownBadInputs)                                                              |
| DDoS / resource exhaustion                          | WAF rate-based rules (global, files/posts)                                                                  |
| Malicious / bad-reputation traffic sources          | WAF IP reputation list                                                                                      |
| Compromised container image / vulnerable dependency | ECR scan-on-push, AWS Inspector continuous rescan                                                           |
| Misconfiguration (open SG, public S3, drift)        | AWS Config rules, Security Hub FSBP/CIS checks                                                              |
| Insider / compromised-credential lateral movement   | IAM least-privilege, IAM Access Analyzer, EventBridge privilege-escalation rules                            |
| Audit trail tampering (anti-forensics)              | CloudTrail log file validation, EventBridge rule on StopLogging/DeleteTrail, S3 Object Lock COMPLIANCE mode |
| Data exposure at rest / in transit                  | KMS CMK encryption, TLS termination at ALB, SSL-only S3 policy                                              |

This mapping is what each control section below expands on.

---

## Security Posture

![security posture](../../assets/img)

### Detection

**1. AI based detection threat - GuardDuty**

GuardDuty uses CloudTrail logs, VPC Flow Logs and DNS query logs to detect threats via machine learning. Findings are pulled and aggregated with other security service findings by Security Hub.

**2. Metric based detection - WAF + CloudWatch Alarm**

WAF is associated with the ALB to protect the application against common threats: SQL injection, DDoS (rate-based limiting), bad reputation IPs, and known CVE payloads. WAF logs are stored in Amazon S3.

CloudWatch Alarms trigger and send alerts through SNS email subscription when WAF metrics (`BlockedRequests`, `login-rate-limit-metric`, `files-posts-rate-limit-metric`, etc.) pass the configured threshold.

WAF is deployed at Regional scope (not CloudFront), since this is a single-region deployment. CloudFront would add cost and a caching layer that complicates Mattermost's session-based traffic without a clear benefit here.

Rate-limit thresholds (200/5min login, 800/5min files-posts, 4000/5min global) were set conservatively based on expected single-team usage patterns rather than tuned against real traffic, this is a documented limitation, not a validated number (see Accepted Tradeoffs).

**3. Vulnerability scanning - AWS Inspector**

To detect application vulnerabilities, the ECR repository is configured with enhanced scanning and scan-on-push enabled. AWS Inspector re-scans automatically when new CVEs are discovered. The findings are routed to Security Hub.

**4. Automated compliance checks & aggregated findings — AWS Security Hub**

Security Hub continuously evaluates two standards, `CIS AWS Foundations Benchmark v5.0.0` and `AWS Foundational Security Best Practices (FSBP)`, and aggregates security/compliance findings from GuardDuty, AWS Inspector, IAM Access Analyzer, and AWS Config.

A single EventBridge rule filters findings from either standard at `HIGH`/`CRITICAL` severity and `Workflow.Status = NEW`, pushing them to SNS.

**5. Event based detection — EventBridge + CloudTrail**

Security Hub findings depend on the underlying service (GuardDuty, Config) detecting an issue first, then Security Hub aggregating it, this pipeline has inherent latency, sometimes several minutes for Config-based findings.

The EventBridge rules in this section match CloudTrail management events directly, reacting near-instantly to the API call itself. Both paths are kept intentionally: Security Hub for aggregated compliance visibility, direct EventBridge rules for low-latency alerting on high-signal events.

| Rule                      | Trigger Events                                                                                                            | Why it matters                                                                                        |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Root account usage        | Any API call by root                                                                                                      | Root has unrestricted access, day-to-day ops should never touch it                                    |
| IAM privilege escalation  | `CreateUser`, `AttachUserPolicy`, `PutRolePolicy`, `AttachRolePolicy`, `PassRole`, `UpdateAssumeRolePolicy`               | `PassRole` is especially high-signal — it lets one principal delegate a role's permissions to another |
| CloudTrail config changes | `StopLogging`, `DeleteTrail`, `UpdateTrail`, `PutEventSelectors`, `PutInsightSelectors`                                   | Disabling CloudTrail is a common technique to erase the audit trail before/during a breach            |
| Security group changes    | `AuthorizeSecurityGroupIngress/Egress`, `RevokeSecurityGroupIngress/Egress`, `CreateSecurityGroup`, `DeleteSecurityGroup` | Most common path to accidentally exposing ECS/RDS to the internet                                     |
| Console login without MFA | Successful `ConsoleLogin` with `MFAUsed=No`                                                                               | Flags credential hygiene failures                                                                     |
| KMS key deletion/disable  | `DisableKey`, `ScheduleKeyDeletion`                                                                                       | `ScheduleKeyDeletion` has a 7–30 day window to cancel before data is unrecoverable                    |
| NACL changes              | `Create/DeleteNetworkAcl(Entry)`, `ReplaceNetworkAclEntry/Association`                                                    | Stateless layer that can silently bypass SG-level controls                                            |

**6. Monitoring and Investigation**

Security Hub provides a dashboard for security findings, compliance violations, IAM drift, and CVE scanning. Amazon Athena queries CloudTrail logs, VPC Flow Logs, ALB access logs, WAF logs, and Config snapshots stored in S3. QuickSight provides dashboards for visibility on top of Athena query results.

Real-time detection (CloudWatch Alarms on WAF metrics, EventBridge-matched CloudTrail events) and after-the-fact investigation (Athena/QuickSight over S3) are deliberately split: metrics/alarms answer "is something happening right now," logs answer "what exactly happened, in detail."

---

### Identity & access management

This project is deployed in a single AWS account to simplify deployment and control costs. In a production enterprise environment, the architecture would typically be extended to a multi-account structure using AWS Organizations with dedicated management, security, logging, development, and production accounts.

The root account uses MFA. Day-to-day operations use an IAM user with least-privilege permissions, nested under a group policy rather than attached directly. ECS tasks and other services use roles with limited permissions.

IAM users beyond root are not currently required to use MFA by policy, absence of MFA on a console login is flagged via the EventBridge rule above (detection), not blocked outright (enforcement). This is an accepted gap for the current single-account setup, not an oversight (see Accepted Tradeoffs below).

IAM Access Analyzer is enabled and detects unintended external access to resources. AWS Config rules are managed by Security Hub to automatically check compliance and detect configuration drift.

---

### Infrastructure protection

AWS WAF is placed as the first layer of defense, protecting against common threats such as: SQL injection, DDoS (rate-based limiting), bad reputation IPs, and known CVE payloads.

Traffic using unsecured protocol (HTTP/80) is redirected to HTTPS/443, and the ALB terminates the TLS connection in the public subnet.

Resources are placed inside private subnets with no outbound access except through VPC Endpoints. The network inside the VPC is segmented by Security Groups with explicit rules.

| Security Group     | Inbound                           | Outbound                                                                   |
| ------------------ | --------------------------------- | -------------------------------------------------------------------------- |
| `alb-sg`           | `0.0.0.0/0` on HTTP/80, HTTPS/443 | `ecs-sg` on TCP/8065                                                       |
| `ecs-sg`           | `alb-sg` on TCP/8065              | `rds-sg` on TCP/5432, `vpc-endpoints-sg` on HTTPS/443, S3 Gateway Endpoint |
| `rds-sg`           | `ecs-sg` on TCP/5432              | None                                                                       |
| `vpc-endpoints-sg` | `ecs-sg` on HTTPS/443             | None                                                                       |

---

### Data protection

The database is placed inside a private subnet with a security group that only allows inbound traffic from the ECS security group. Database credentials are stored in SSM SecureString.

RDS PostgreSQL and S3 data storage are encrypted with a customer-managed KMS key (CMK), with key rotation every 90 days, and API calls to S3 are restricted to SSL connections only. This setup ensures data is protected both at rest and in transit.

A customer managed KMS key (CMK) was selected instead of an AWS-managed KMS key to provide fine-grained control over key usage. The CMK key policy allows encryption and decryption permissions to be explicitly scoped to authorized IAM principals and AWS services (for example, CloudTrail), whereas the key policy of an AWS-managed KMS key cannot be customized by the customer.

---

### Application security

The Docker container runs as a non-root user (`mattermost`). Root (UID 0) is never used at runtime, reducing the impact of a container-level compromise.

ECR is configured with scan-on-push (enhanced scanning) and continuous scanning by AWS Inspector, which re-scans automatically as new CVEs are disclosed.

---

## Incident Response

This runbook defines the process for preparation, detecting, investigating, containing, eradicating, and recovering from security incidents affecting the AWS environment. It ensures incidents are handled consistently while minimizing business impact.

**1. Preparation**

- Vulnerability scanning (AWS Inspector)
- Security hardening (explicit ACLs, SGs, VPC Endpoints, IAM, etc.)
- Tuning preventive and detection tools (WAF, AWS Config rules, EventBridge rules, etc.) based on lessons learned
- Threat hunting (kill chain / ATT&CK campaign simulation)
- Modify or update the incident response runbook

**2. Detection**

Detection sources:

- GuardDuty findings
- Security Hub findings
- AWS Config compliance violations
- CloudWatch alarms
- CloudTrail events
- WAF blocked requests

Trigger — an incident begins when one of the following occurs:

- High or Critical GuardDuty finding
- Security Hub High/Critical finding
- CloudWatch alarm
- AWS Config rule becomes NON_COMPLIANT
- Suspicious CloudTrail activity

Initial actions:

- Determine severity
- Record details (IP addresses, detection time, affected resource, AWS Account ID, Finding ID, etc.)

**3. Triage**

Prioritize which alerts are worth investigating (severity), determine if the alert is genuine or a false positive, which resources are affected, current impact, and possible attacker activity.

**4. Investigation**

Collect evidence, aggregate and review historical log context (Security Hub / Athena+QuickSight), and apply the MITRE ATT&CK framework to check for common attack tactics, techniques, and procedures.

**5. Containment**

Isolate affected resources (restrict ACL/SG access, block attacker IP using WAF, etc.), disable compromised users, remove access keys, stop compromised tasks, etc.

IP blocking during containment is automated by Lambda function triggered by WAF finding that updates an IP set automatically. Other finding required manual containment. Known limitation :

- Other findings required manual response
- No retry/error handling, acceptable for a lab-scale automation, would add try/except + backoff for production.
- Predictif Treshold (required testing and tunning in real trffics).

**6. Eradication**

Remove the root cause. Examples:

- Patch vulnerable application
- Remove malicious container image
- Update IAM policies
- Remove unused access keys
- Enable MFA
- Delete unauthorized resources

**7. Recovery**

Restore production and monitor the environment for 24–48 hours. Verify:

- ECS healthy
- ALB healthy
- Mattermost accessible
- No active GuardDuty findings
- Security Hub findings resolved
- Config resources compliant
- CloudWatch alarms cleared

**8. Lessons Learned**

Conduct a post-incident review: document the timeline, root cause, detection source, impact, response actions, recovery time, preventive actions, and evaluate the incident response runbook.

---

## Components delivered

| Component                  | Decision rationale                                                                                                                                                                                                                                                                                                                    |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CloudTrail                 | Multi-region management event capture, data events on Mattermost S3 storage only, log file validation enabled.                                                                                                                                                                                                                        |
| VPC Flow Logs              | Shared `security_logs` S3 bucket, KMS CMK, captures metadata for all traffic types.                                                                                                                                                                                                                                                   |
| ALB                        | ALB access logs enabled, shared `security_logs` S3 bucket, KMS CMK.                                                                                                                                                                                                                                                                   |
| WAF + S3                   | WAF blocked logs stored in shared `security_logs` S3 bucket, KMS CMK, Block mode, `AWSManagedRulesCommonRuleSet`, `AWSManagedRulesKnownBadInputsRuleSet`, `AWSManagedRulesSQLiRuleSet`, `AWSManagedRulesAmazonIpReputationList`, `global-rate-limit (4000/5min)`, `files-posts-rate-limit (800/5min)`, `login-rate-limit (200/5min)`. |
| CloudWatch Alarm + SNS     | Alarms on WAF metrics (`BlockedRequests` and per-rule metrics), notifying via existing SNS email subscription.                                                                                                                                                                                                                        |
| Clodwatch Alarm + Lambda   | Treshold 100/5min, Rule matric = `BlockedRequests`, boto3. time window 5min, max item 100.                                                                                                                                                                                                                                            |
| AWS Config                 | CONTINUOUS, all resource types, shared `security_logs` S3 bucket, KMS CMK, Config rule for resource tagging.                                                                                                                                                                                                                          |
| AWS GuardDuty              | Enabled, findings routed to Security Hub.                                                                                                                                                                                                                                                                                             |
| AWS Inspector              | Enabled, findings routed to Security Hub.                                                                                                                                                                                                                                                                                             |
| AWS IAM Access Analyzer    | Type = "ACCOUNT".                                                                                                                                                                                                                                                                                                                     |
| AWS Security Hub           | Classic CSPM and Security Hub v2: `foundational-security-best-practices/v/1.0.0`, `cis-aws-foundations-benchmark/v/5.0.0`, `product/aws/guardduty`, `product/aws/inspector`.                                                                                                                                                          |
| S3 (`logs`) + KMS          | S3 with COMPLIANCE object lock, versioning enabled, lifecycle tiering to IA → Glacier IR → Deep Archive, SSE-KMS with CMK, key rotation enabled, 30-day deletion window.                                                                                                                                                              |
| EventBridge + SNS          | Captures CloudTrail events that violate CIS Benchmark v5.0, routes to SNS topics for notification.                                                                                                                                                                                                                                    |
| Glue + Athena + QuickSight | SQL query interface over shared S3 `security_logs` bucket for investigation.                                                                                                                                                                                                                                                          |

---

## Accepted Tradeoffs

| Tradeoff                                                                                      | Reason                                                                                                                                                                                                                                                                                                                                 |
| --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Single AWS account                                                                            | Simplifies infrastructure management and reduces operational overhead. Accepts reduced workload isolation and larger blast radius compared to a multi-account architecture, with migration planned as organizational maturity increases.                                                                                               |
| CloudTrail data events enabled for Mattermost S3 data events only                             | Balances CloudTrail cost against log volume. `security_logs` bucket are protected with object lock and compliance mode.                                                                                                                                                                                                                |
| SSM secure string over AWS secret manager                                                     | SSM is free, but not offer automated rotation wich better approach acording to FSBP.                                                                                                                                                                                                                                                   |
| Baseline WAF rules and direct Block mode for custom rate-limit rules                          | "Fancy" rue group like bot/fraud control are expensive. the the tradeoff is it might not be sufficient for a sophisticated attacker. directly set block mode without a testing/tuning period risks blocking legitimate traffic. In a real environment, Count mode would run for a few days/weeks for tuning before switching to Block. |
| WAF blocked logs only                                                                         | Investigation/forensics may lack full traffic context (allowed requests aren't logged).                                                                                                                                                                                                                                                |
| CW Alarm + Lambda Predictif treshold                                                          | Not tested in real trffic, potential for autoblock legitimete IP's, required testing and tunning in real prod env. for now security team required to check if the auto blocked ip is not false positive.                                                                                                                               |
| Athena + QuickSight                                                                           | Adds management overhead and complexity compared to a managed SIEM.                                                                                                                                                                                                                                                                    |
| WAF, VPC Flow Logs, CloudTrail, ALB access logs ingested to shared S3 bucket only             | No real-time monitoring via CloudWatch Logs Insights (which requires logs to be ingested into a CloudWatch Log Group); real-time detection instead relies on WAF CloudWatch metrics + Alarms.                                                                                                                                          |
| Rate-limit thresholds untested against real traffic                                           | No production traffic available to tune against in a deploy-and-destroy lab; values are conservative estimates, not validated baselines.                                                                                                                                                                                               |
| IP blocking is manual, not automated                                                          | Automating containment (Lambda + WAF IP set update) is scoped for Phase 3.                                                                                                                                                                                                                                                             |
| MFA enforced on root only, IAM users flagged (not blocked) via EventBridge rule if MFA absent | Full IAM MFA enforcement (e.g. via Config rule / SCP) not yet implemented in this single-account setup.                                                                                                                                                                                                                                |

---

## Validation

- WAF blocked logs stored in S3
- Security team receives email notification from WAF metric + CloudWatch Alarm + SNS topic
- Security Hub dashboard operational
- Security bucket contains VPC Flow Logs, WAF logs, ALB access logs, CloudTrail, and AWS Config snapshots
- Email notification received from CloudTrail event and Security Hub findings
- S3 bucket Object Lock COMPLIANCE mode denies bucket/object deletion attempts

> The domain is not permanently live. The stack uses a deploy-and-destroy model — it is spun up during active lab sessions and torn down afterward to control cost. The screenshot above is the validation artifact.

---

## Issues Encountered

<!--
Real debugging issues hit during Phase 1 — ECS role confusion, URI encoding in the DSN, and Terraform security group dependency cycles — are documented in [Lessons Learned](../lessons-learned/index.md).
-->

---

## Next Phase

<!-- [Phase 2 — AWS Well-Architected 6 Pillars →](phase-2-well-architected.md) -->
