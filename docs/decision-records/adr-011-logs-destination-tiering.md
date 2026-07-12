# ADR-011 — Log Destination Tiering: CloudWatch Logs vs. S3

**Date:** 2026-07-13
**Status:** Accepted

---

## Context

This project's security telemetry originates from multiple sources: CloudTrail, VPC Flow Logs, ALB access logs, WAF, ECS application logs, and RDS logs. Two viable destinations exist for any of them: CloudWatch Logs (fast, queryable via Logs Insights, retention-capped, cost scales with ingestion) and S3 (cheap at scale, queryable via Athena with higher latency, supports indefinite retention and Object Lock immutability).

Three findings this session forced a formal decision rather than an ad hoc per-source choice:

- WAF's `logging_filter` keeps only BLOCK and COUNT actions
  ALLOW traffic is dropped by design (there already alb access logs). This means WAF logs were never going to serve as a general forensic record the way CloudTrail or full-traffic VPC Flow Logs do. Their only real value is rule tuning, threshold testing, and quick investigation of what WAF already stopped. CloudWatch Logs Insights provide easy and real-time queryng which better fit for this purpose.

- AWS mandates that any WAF log destination
  S3 bucket or CloudWatch log group have a name starting with `aws-waf-logs-`. This ruled out reusing the existing shared `security_logs` bucket specifically, meaning a dedicated destination was required either way.

These three findings meant the logging architecture needed an explicit, documented split rather than defaulting everything to one destination.

---

## Decision

Split log destinations by use case, not by source type:

- **CloudWatch Logs** (30-day retention, queried via Logs Insights): ECS application logs, RDS logs, CloudTrail management events, WAF BLOCK/COUNT logs. These are the sources most useful for fast, recent-window investigation and rule/threshold tuning, not long-term forensic replay.
- **S3** (queried via Athena): CloudTrail, VPC Flow Logs, ALB access logs, Configs. These are the sources where long-term retention and full traffic visibility matter more than query speed.

---

## Reasoning

| Factor                            | CloudWatch Logs                              | S3                                                            |
| --------------------------------- | -------------------------------------------- | ------------------------------------------------------------- |
| Query latency                     | Seconds, via Logs Insights                   | Higher latency, via Athena/Glue                               |
| Retention model                   | Fixed, cost scales with retention length     | Cheap at scale, supports indefinite retention                 |
| Immutability (Object Lock)        | Not supported                                | Supported (COMPLIANCE/GOVERNANCE modes)                       |
| `aws-waf-logs-` naming constraint | Applies to log group name                    | Applies to bucket name                                        |
| Best fit                          | Fast, recent-window investigation and tuning | Long-term forensic retention, full traffic history            |
| Sources assigned                  | ECS, RDS, WAF                                | VPC Flow Logs (ALL), ALB access logs, Configs, and CloudTrail |

The deciding factor for WAF specifically was not a preference between the two destinations in the abstract, it was that the shared `security_logs` bucket, already used for every other S3-tier source, could not be reused for WAF without a second dedicated bucket. Given a dedicated destination was required either way, CloudWatch Logs was chosen because the actual use case (rule tuning, quick investigation) matches Logs Insights better than Athena.

---

## Tradeoffs

WAF log retention capped at 30 days: Unlike CloudTrail, VPC Flow Logs, and ALB logs (which retain indefinitely in S3), WAF logs age out after 30 days. An incident investigated more than a month after the fact loses WAF-specific evidence; the other three sources still provide coverage.

High volume loggs : Enabling high volume of logs increases both S3 storage and Athena scan cost per query. Cost exposure is bounded by the deploy-and-destroy model, this bucket does not accumulate data across long-lived sessions the way a persistent production account would.

No real-time Monitoring for CloudTrail, VPC flow logs etc. Enabling CW Insight required logs to be ingested to CW log group first. But by doing so it will significantly increase the cost both for data ingestion and CW log storage, furthermore this logs are valuable for forensic, so long term retention like s3 are needed anyway.

---

## Consequences

- WAF, ECS, and RDS logs are queryable in near-real-time via CloudWatch Logs Insights; CloudTrail, VPC Flow Logs, and ALB logs require Athena and have higher query latency.
- The `security_logs` S3 bucket no longer receives WAF logs; a new dedicated CloudWatch log group (`aws-waf-logs-...` prefix) exists solely for WAF.
- VPC Flow Logs capture full traffic, not just rejections, closing the forensic gap around allowed-but-malicious traffic.
- `dev` deployments never trigger Object Lock COMPLIANCE mode; `prod`-tier values (365-day compliance lock, 395-day total expiration) exist in `.tfvars` as documented but inactive configuration.
- If a future requirement needs WAF log retention beyond 30 days, the known alternative is a CloudWatch Logs subscription filter to Kinesis Firehose → S3, added without modifying the WAF resource itself.
