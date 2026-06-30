### Components delivered

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
