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
