# ADR-005 — EventBridge over CloudWatch Metric Filters for CIS Benchmark Alerting

**Date:** 2026-06
**Status:** Accepted

---

## Context

The infrastructure implements security monitoring aligned with selected CIS AWS Foundations Benchmark controls.

Security-relevant activities such as IAM changes, CloudTrail modifications, root account usage, security group changes, and other management events are captured by CloudTrail.

AWS provides multiple approaches for generating alerts from these events:

1. CloudTrail → CloudWatch Logs → Metric Filters → CloudWatch Alarms → SNS
2. CloudTrail → EventBridge → SNS

Both approaches can detect and notify on security events, but they differ in architecture, cost model, and operational complexity.

---

## Decision

Use EventBridge rules with SNS notifications for CIS benchmark alerting instead of CloudWatch metric filters and alarms.

---

## Reasoning

| Factor                 | EventBridge         | CloudWatch Metric Filters |
| ---------------------- | ------------------- | ------------------------- |
| Cost                   | Lower               | Higher                    |
| Architecture           | Simpler             | More components           |
| Alert latency          | Near real-time      | Near real-time            |
| Log ingestion required | No                  | Yes                       |
| CloudWatch dependency  | None                | Required                  |
| Operational overhead   | Lower               | Higher                    |
| Best use case          | Event-driven alerts | Metrics and thresholds    |

EventBridge subscribes to CloudTrail at the AWS service layer directly not from S3 or CloudWatch Logs.

Because the objective is event-driven security alerting rather than metric analysis, EventBridge provides a simpler and more cost-efficient architecture. Rules can filter specific CloudTrail API events and immediately forward matching events to SNS for notification.

This approach eliminates CloudWatch log ingestion costs, CloudWatch metric filter configuration, and CloudWatch alarm management while still achieving the required security monitoring objectives.

Moreover, several CIS controls are not achievable via CloudWatch metric filters at all. Some were removed from the CIS benchmark entirely, others are marked as manual checks

---

## Tradeoffs

**Reduced metric visibility:** CloudWatch metric filters create metrics that can be visualized, aggregated, and analyzed over time. EventBridge focuses on individual events rather than trend analysis.

**Less suitable for threshold-based detection:** CloudWatch alarms are better suited for scenarios requiring counts, rates, or statistical thresholds.

**Different operational model:** Engineers must understand event-driven filtering rather than metric-based alerting.

These limitations are acceptable because the primary requirement is immediate notification of security-relevant management events.

---

## Consequences

- Security alerts are generated directly from CloudTrail events.
- CloudWatch log ingestion costs are avoided.
- Alerting architecture is simpler and easier to maintain.
- SNS notifications remain near real-time.
- CloudWatch can still be introduced later if advanced metric-based detections become necessary.
