# ADR-002 — SSM Parameter Store over Secrets Manager

**Date:** 2026-05
**Status:** Accepted

---

## Context

The Mattermost ECS task requires a PostgreSQL DSN at startup. This credential must be stored securely and injected into the container without baking it into the image or passing it as a plaintext environment variable.

The two primary AWS-native options are SSM Parameter Store (`SecureString`) and AWS Secrets Manager.

---

## Decision

Use SSM Parameter Store for Phase 1.

---

## Reasoning

| Factor               | SSM Parameter Store                           | Secrets Manager                               |
| -------------------- | --------------------------------------------- | --------------------------------------------- |
| Cost                 | Free (Standard tier `SecureString`)           | $0.40/secret/month + $0.05 per 10k API calls  |
| ECS integration      | Native via `secrets` block in task definition | Native via `secrets` block in task definition |
| Automatic rotation   | No                                            | Yes (Lambda-backed)                           |
| Cross-account access | Limited                                       | Supported                                     |
| Fit for Phase 1      | Yes                                           | Overkill for a single static credential       |

For a single static credential in a lab environment, Secrets Manager's rotation and cross-account features provide no benefit and add cost. SSM `SecureString` covers the use case for free.

---

## Known Limitation

Because Terraform writes the DSN to SSM, the value also ends up in `.tfstate` in plaintext. For a local-state lab setup this is an accepted tradeoff, but it is documented here rather than glossed over.

A production setup would require one of:

- A remote backend (S3) with encryption and tightly-scoped access controls on the state file
- An approach that avoids passing the DSN through Terraform entirely — for example, constructing the DSN at runtime inside the container, or using Secrets Manager's native ECS integration which avoids the Terraform-managed write path

---

## Consequences

- No additional cost for Phase 1 secrets management.
- Credential rotation is manual — acceptable for a lab environment with a single static credential.
- DSN is present in local `.tfstate` in plaintext — acceptable for a lab, unacceptable for production.
