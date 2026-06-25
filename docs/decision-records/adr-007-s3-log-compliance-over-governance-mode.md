# ADR-007 — S3 Object Lock Compliance Mode over Governance Mode

**Date:** 2026-06
**Status:** Accepted

---

## Context

The platform generates security and audit logs through CloudTrail and other security monitoring services. These logs serve as evidence during incident investigations, compliance validation, forensic analysis, and operational audits.

Amazon S3 Object Lock provides write-once-read-many (WORM) protection that prevents objects from being modified or deleted before their retention period expires. Object Lock requires versioning to be enabled on the bucket and supports two protection modes:

- **Governance Mode** — users with specific IAM permissions can bypass retention controls and delete or modify protected objects before retention expires.
- **Compliance Mode** — no user, including the root account, can modify, shorten, or delete protected objects until the retention period expires.

Because security logs represent a system of record during investigations, maintaining their integrity takes priority over operational flexibility.

---

## Decision

Use S3 Object Lock in Compliance Mode with a 365-day retention period for security log storage.

---

## Reasoning

| Factor                   | Compliance Mode              | Governance Mode                       |
| ------------------------ | ---------------------------- | ------------------------------------- |
| Protection strength      | Highest                      | Moderate                              |
| Privileged-user bypass   | Not allowed — including root | Allowed with specific IAM permissions |
| Log integrity            | Strongest available          | Good                                  |
| Regulatory alignment     | Strong                       | Moderate                              |
| Operational flexibility  | Lower                        | Higher                                |
| Forensic trustworthiness | Highest                      | Good                                  |

Security logs must remain trustworthy even if an administrator account becomes compromised. Governance Mode allows sufficiently privileged IAM users to bypass retention controls and delete protected objects before retention expires.

While this provides operational flexibility, it creates a potential avenue for log tampering by malicious actors or compromised privileged accounts.

Compliance Mode removes this capability entirely. Once an object is written and a retention period applied, it cannot be modified, shortened, or deleted until the 365-day retention period expires — regardless of the caller's IAM permissions or account privileges.

---

## Tradeoffs

**Reduced flexibility:** Mistakenly configured retention periods cannot be shortened or removed before expiry.

**Operational mistakes are harder to correct:** Incorrectly stored objects remain locked until retention expiration. Changes to retention policies must be carefully reviewed before deployment.

**Versioning is required:** S3 Object Lock requires bucket versioning to be enabled. This adds minor storage overhead for versioned objects but is required for WORM protection to function.

These limitations are acceptable because preserving audit log integrity is more important than administrative convenience.

---

## Consequences

- Security logs are effectively immutable for 365 days from the date of writing.
- Bucket versioning is enabled as a required dependency of Object Lock.
- Incident investigations can rely on stronger evidence integrity guarantees.
- Privileged-user and root account log tampering risk is eliminated during the retention window.
- Administrative flexibility is reduced in favor of stronger integrity controls.
