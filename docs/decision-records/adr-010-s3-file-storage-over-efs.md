# ADR-010 — S3 for Mattermost File Storage (EFS Deferred / Not Required)

**Date:** 2026-06-28  
**Status:** Accepted

---

## Context

Fargate containers have no persistent local disk. When a task is replaced due to a deployment, health check failure, or scaling event, the container filesystem is wiped. Mattermost's default file storage driver writes to the local filesystem, which means any file uploaded by a user would be permanently lost on the next task replacement.

Persistent file storage is therefore required. Two options were evaluated: Amazon EFS and Amazon S3.

The project has no NAT Gateway. All outbound connectivity from private subnets to AWS services is handled by VPC Endpoints. Any storage solution must be reachable within this constraint at acceptable cost.

---

## Decision

Use Amazon S3 for Mattermost file storage via Mattermost's native `amazons3` driver.

---

## Reasoning

| Factor                  | EFS                                               | S3                                              |
| ----------------------- | ------------------------------------------------- | ----------------------------------------------- |
| Fargate compatibility   | Supported via volume mount                        | Supported via native Mattermost driver          |
| Endpoint requirement    | Requires EFS VPC Endpoint (not provisioned)       | Gateway Endpoint already deployed               |
| Idle cost               | ~$0.30/GB-month; charges continue when idle       | Per-request and per-GB; zero cost when empty    |
| Deploy-and-destroy fit  | Poor — persistent charges conflict with lab model | Good — no idle cost on teardown                 |
| Network config overhead | Mount targets per AZ, NFS SG rule (TCP/2049)      | No additional endpoints or security group rules |
| Application changes     | None — transparent POSIX mount                    | Environment variable configuration only         |
| Filesystem semantics    | Full POSIX                                        | Object store — no file locking or directory ops |
| Phase 1 fit             | Premature; over-engineered for a single workload  | Sufficient                                      |

The S3 Gateway Endpoint is already deployed to support ECR image layer pulls. Reusing it for Mattermost file storage adds no infrastructure cost and no architectural complexity. EFS would require a new VPC Endpoint, mount targets across two AZs, NFS security group rules, and ongoing per-GB charges that conflict with the project's deploy-and-destroy lab model.

---

## Tradeoffs

**No POSIX filesystem semantics:** S3 is an object store, not a filesystem. File locking and directory operations are not supported. Mattermost does not currently require these semantics, but if a future version does, EFS would need to be revisited.

**Authorization model shift:** Mattermost enforces access control via RDS and acts as the sole intermediary for S3. Users have no direct bucket access. This is simpler than managing per-user EFS access points but is a different trust boundary than a mounted volume.

**Bucket lifecycle management required:** Versioning is enabled to support accidental deletion recovery. Noncurrent object expiration at 90 days prevents indefinite storage growth. `force_destroy = true` is set in the dev environment to allow clean teardown; this must be explicitly set to `false` in any environment where data must be preserved.

---

## Consequences

- Files uploaded by Mattermost users persist across task replacements and redeployments.
- No additional VPC Endpoints, mount targets, or security group rules are required.
- The ECS task role requires `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, and `s3:ListBucket` on the bucket.
- The bucket is encrypted with a CMK; `bucket_key_enabled = true` reduces per-object KMS API call cost.
- Versioning with 90-day noncurrent expiration is enabled for durability without unbounded growth.
- If Mattermost ever requires POSIX filesystem semantics, EFS would need to be re-evaluated.
