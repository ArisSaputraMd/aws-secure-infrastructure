# ADR-013 — CloudTrail Data Events Scoped to the Mattermost Application Bucket Only

**Date:** 2026-07-13
**Status:** Accepted

---

## Context

CloudTrail supports two event types: management events (control-plane API calls, creating/modifying/deleting resources) and data events (data-plane operations, individual object-level `GetObject`, `PutObject`, `DeleteObject` calls on S3). Data events are charged and billed per event, and cost scales directly with request volume, unlike management events.

This project has two S3 buckets where data-event logging is relevant:

- The Mattermost application bucket (S3 file storage), which holds user-uploaded files, is mutable, and is directly reachable by the application on behalf of end users.
- The `security_logs` bucket, which holds CloudTrail's own management-event trail, VPC Flow Logs, and ALB access logs. This bucket runs with S3 Object Lock in COMPLIANCE mode. Objects cannot be deleted or overwritten by any principal, including root, until retention expires.

> In `dev`, Object Lock is disabled and the bucket is fully mutable, matching the deploy-and-destroy model.

Logging data events on both buckets uniformly would double the object-level event volume without a proportional increase in security value, since the two buckets have very different risk profiles and different reasons for being lower priority to monitor at the object level.

---

## Decision

Enable CloudTrail data events for S3 object-level operations on the Mattermost application bucket only. Data events are not enabled for the `security_logs` bucket.

---

## Reasoning

| Factor                                       | Mattermost application bucket                                                                      | `security_logs` bucket                                                                                                                                                                    |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mutability                                   | Fully mutable, always                                                                              | COMPLIANCE lock in `prod`                                                                                                                                                                 |
| Reachable by end users (indirectly, via app) | Yes                                                                                                | No — write path is CloudTrail/Flow Logs/ALB delivery only, no user-facing access                                                                                                          |
| Realistic tamper/exfiltration target         | Yes, user uploaded files are the actual data an attacker would want to read, modify, or exfiltrate | Low in `prod` (Object Lock prevents modification outright)                                                                                                                                |
| Value of object-level audit trail            | High, this is where unauthorized access or data manipulation would actually show up                | Low, the bucket has no direct external access surface, so object-level events here would almost entirely reflect the project's own logging pipelines writing to it, not attacker activity |
| Cost impact                                  | Justified, this is the bucket where object-level visibility matters                                | Not justified, near zero marginal security value for ongoing per-event cost                                                                                                               |

The application bucket is the one with an actual attack surface at the object level, it's written to and read from based on user action inside Mattermost, so its object-level audit trail is where a real tampering or exfiltration attempt would likelly appear. The `security_logs` bucket's (`prod` env), Object Lock reduces the marginal value of data events on `security_logs`, since successful delete/overwrite is already prevented outright by S3 itself, not just logged after the fact.

---

## Tradeoffs

**No CloudTrail record of attempted (failed) tampering on `security_logs` in `prod`.** Object Lock COMPLIANCE mode prevents an attacker from successfully deleting or overwriting a locked object, but without data events on this bucket, there is no CloudTrail record that someone _tried_. A failed delete attempt against a locked audit-log object is itself a strong compromise signal, and this design has no visibility into it. Accepted here because the project has no other detective control on that bucket's data plane, and adding one would reintroduce the cost this decision is meant to avoid. worth revisiting if budget allows toward a real incident-response capability.

**In `dev`, this decision isn't backed by Object Lock at all.** Since Object Lock is off in `dev`, the `security_logs` bucket there is genuinely unmonitored at the object level with no compensating immutability control — the decision to skip data events in `dev` rests on "lab environment, low realistic risk, cost control," not on the bucket being tamper-proof. That's a reasonable call for a lab, but it should be stated as its own reason in documentation, not folded into the immutability argument that only holds in `prod`.

**Management-event coverage on `security_logs` itself is unaffected.** This decision only concerns S3 data events (object-level operations). CloudTrail management events (e.g., changes to the bucket's own configuration, policy, or Object Lock settings) continue to be captured under the existing multi-region trail, regardless of this decision.

---

## Consequences

- CloudTrail data-event cost is bounded to the one bucket where object-level activity has real investigative value.
- Object-level access to user-uploaded Mattermost files (read, write, delete) is fully auditable via CloudTrail.
- The `security_logs` bucket has no object-level CloudTrail audit trail of its own; its integrity in `prod` relies on Object Lock preventing tampering outright, and in `dev` relies on the bucket having no realistic attacker-facing access path rather than any compensating control.
- If a future requirement needs to detect _attempted_ tampering against `security_logs` (not just prevent successful tampering), data events would need to be enabled there too, reintroducing the cost this ADR avoids.
