# ADR-009 — Local Terraform State for Phase 1 (Remote Backend Deferred to Phase 3)

**Date:** 2026-05
**Status:** Accepted

---

## Context

Terraform requires a state file to track infrastructure resources and determine the changes required during future operations.

Terraform supports multiple backend options for state storage. The simplest approach is local state, where the state file is stored on the engineer's workstation. Production deployments typically use a remote backend (an S3 bucket for state storage combined with a DynamoDB table for state locking) to provide centralized storage, concurrent operation protection, and durability.

This project is developed and operated by a single engineer from a single workstation. There are no concurrent operators and no CI/CD pipeline in Phase 1.

Two accepted risks are present with local state:

1. **Credential exposure:** Terraform writes the database DSN to SSM Parameter Store, which causes the plaintext DSN value to be stored in `.tfstate`. Local state provides no encryption or access controls on that file beyond filesystem permissions. This is documented as a known limitation in [ADR-002](./adr-002-ssm-parameter-store-over-secrets-manager.md).

2. **State durability:** Loss or corruption of the local state file can complicate infrastructure recovery and require manual state reconstruction.

Both risks are accepted for Phase 1 and addressed in later phases.

---

## Decision

Use local Terraform state during Phase 1 and implement a remote backend in Phase 3 alongside CI/CD automation.

---

## Reasoning

| Factor              | Local State             | Remote Backend (S3 + DynamoDB)                   |
| ------------------- | ----------------------- | ------------------------------------------------ |
| Setup complexity    | Very low                | Higher — additional AWS resources required       |
| Cost                | None                    | Minor — S3 storage and DynamoDB read/write costs |
| Team collaboration  | Not supported           | Supported                                        |
| State locking       | Not available           | Available via DynamoDB lock table                |
| State durability    | Depends on local backup | High — S3 durability                             |
| State encryption    | None                    | S3 SSE with scoped IAM                           |
| CI/CD compatibility | Not compatible          | Required for GitHub Actions                      |
| Phase 1 fit         | Sufficient              | Premature without a pipeline                     |

A remote backend provides no collaboration benefit in a single-engineer environment with no CI/CD pipeline. Introducing it in Phase 1 adds infrastructure overhead without meaningful benefit at this stage.

Remote state is a hard prerequisite for Phase 3 CI/CD. GitHub Actions cannot use local state — the state file does not exist on the runner. The remote backend implementation is therefore scheduled alongside pipeline development in Phase 3 rather than as an isolated Phase 1 task.

---

## Tradeoffs

**Credential exposure in `.tfstate`:** The plaintext DSN in local state is an accepted security risk for Phase 1. A remote backend with S3 SSE and tightly-scoped IAM access controls would significantly reduce this exposure. This is the primary security reason to migrate, not just an operational one.

**No state locking:** Concurrent Terraform operations are unprotected. This is acceptable because the environment is managed by a single operator with no parallel workflows.

**State durability depends on local backups:** Local state loss can complicate recovery. Acceptable for a lab environment where infrastructure can be redeployed from source.

---

## Consequences

- Terraform setup remains simple with no additional AWS resources required.
- The plaintext DSN in `.tfstate` is an accepted Phase 1 security limitation.
- State durability depends on local backup practices.
- Migration to an S3 backend with DynamoDB state locking is a hard prerequisite for Phase 3 CI/CD and is planned for that phase.
- This decision will be superseded when the remote backend is implemented in Phase 3.
