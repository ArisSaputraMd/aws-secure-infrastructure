# ADR-006 — S3 and Athena over CloudWatch Logs Insights for Security Investigation

**Date:** 2026-06
**Status:** Accepted

---

## Context

CloudTrail logs must be retained for auditing, compliance validation, incident investigation, and operational troubleshooting.

AWS provides multiple approaches for querying and analyzing CloudTrail data:

1. Store logs in CloudWatch Logs and investigate using CloudWatch Logs Insights.
2. Store logs in Amazon S3 and query them using Amazon Athena.

The project requires long-term retention of CloudTrail logs and the ability to perform investigations when security alerts are generated.

---

## Decision

Use Amazon S3 as the primary CloudTrail log destination and Amazon Athena for log investigation instead of CloudWatch Logs Insights.

---

## Reasoning

| Factor                 | S3 + Athena                          | CloudWatch Logs Insights                 |
| ---------------------- | ------------------------------------ | ---------------------------------------- |
| Storage cost           | Lower                                | Higher                                   |
| Long-term retention    | Excellent                            | More expensive                           |
| Query capability       | Strong SQL-based analysis            | Strong log analysis                      |
| Scalability            | High                                 | High                                     |
| Compliance suitability | Excellent                            | Good                                     |
| Operational model      | Query when needed                    | Continuous log ingestion                 |
| Cost efficiency        | Better for infrequent investigations | Better for frequent operational analysis |

CloudTrail logs are primarily retained for auditability and occasional investigation rather than continuous operational monitoring.

S3 provides highly durable, low-cost storage and more importanly it provide COMPLIANCE mode object lock. Logs cannot be deleted or overwritten for 365 days, even by the root account. CloudWatch Logs has no equivalent guarantee.

Athena allows logs to be queried on demand using standard SQL without requiring continuous ingestion into CloudWatch Logs.

Because investigations are expected to be relatively infrequent, the pay-per-query model of Athena provides better cost efficiency than continuously storing large volumes of logs in CloudWatch Logs.

This architecture also aligns with common security and compliance patterns where logs are retained in immutable storage and queried only when necessary.

---

## Tradeoffs

**Higher investigation latency:** Athena queries are not as immediate as searching data already available in CloudWatch Logs.

**Additional setup complexity:** Athena requires table definitions and query configuration before investigations can be performed.

**Less suitable for operational troubleshooting:** CloudWatch Logs provides a better experience for teams that frequently analyze application and infrastructure logs.

These limitations are acceptable because the project prioritizes secure log retention, immutable and cost-efficient investigation capabilities over real-time log analytics.

---

## Consequences

- CloudTrail logs are retained in low-cost, durable storage.
- Investigation capability remains available through Athena SQL queries.
- CloudWatch Logs storage and ingestion costs are avoided.
- Security monitoring uses EventBridge for alerting while Athena supports post-alert investigation.
- The architecture reflects a cost-conscious security logging strategy appropriate for a small environment.
