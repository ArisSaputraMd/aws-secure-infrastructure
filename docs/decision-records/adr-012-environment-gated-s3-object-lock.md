# ADR-012 — Environment-Gated S3 Object Lock for `security_logs` Bucket

**Date:** 2026-07-13
**Status:** Accepted

---

## Context

The `security_logs` S3 bucket stores CloudTrail, VPC Flow Logs, Configs and ALB access logs for The project's long-term forensic record. A production-grade version of this bucket should carry S3 Object Lock in COMPLIANCE mode (imutable). This is standard practice for tamper-evident audit logging and directly supports the threat model's "audit trail tampering (anti-forensics)" control.

This project also runs on a deploy-and-destroy lab model: `terraform destroy` is run at the end of every working session to control cost, and the entire stack including `security_logs` is expected to tear down cleanly every time.

These two requirements are in direct conflict. S3 Object Lock COMPLIANCE mode is, by design, un-bypassable: AWS documents no override, no force-delete, and no root-level exception. The only way to remove a COMPLIANCE-locked object before its retention date is to delete the entire AWS account. If COMPLIANCE mode were active on `security_logs` in the `dev` environment, `terraform destroy` would fail on that bucket the moment it contained a single locked object, and would continue failing for the length of whatever retention period was configured — potentially up to a year, per the production-tier value under consideration (365-day compliance lock).

A decision was needed on how to get real COMPLIANCE-mode behavior documented and ready for a production deployment, without breaking the lab's core cost-control mechanism.

---

## Decision

Gate S3 Object Lock, `force_destroy`, and compliance retention length behind Terraform variables, with different values per environment:

```hcl
# dev.tfvars
logs_bucket_object_lock   = false
logs_bucket_force_destroy = true
bucket_compliance_days    = 1

# prod.tfvars (documented, not active)
logs_bucket_object_lock   = true
logs_bucket_force_destroy = false
bucket_compliance_days    = 365
```

`dev` env should not enables Object Lock, so `security_logs` remains fully destroyable every session. The production configuration COMPLIANCE mode, `force_destroy = false`, 365-day retention is fully specified in Terraform but only activated by supplying `prod.tfvars`, which has been applied against a live account with only 1 day retention.

---

## Reasoning

| Factor                                     | Object Lock always on                                                                              | Object Lock environment-gated (chosen)                                             |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Deploy-and-destroy compatibility           | Broken — `terraform destroy` fails once any object is locked                                       | Preserved in `dev`; only activates where torn-down cycles aren't expected          |
| Demonstrates production-grade design       | Yes, but untestable without risking a stuck bucket                                                 | Yes — fully specified, reviewable, and explained in Terraform and ADR              |
| Risk of accidental lock-in during lab work | High — a single `apply` with the wrong var value could leave a bucket undeletable for up to a year | Low — `dev` default is `false`, prod values require deliberate `.tfvars` selection |
| Resource duplication                       | None either way — same `aws_s3_bucket` resource, value-driven                                      | None either way — same `aws_s3_bucket` resource, value-driven                      |

Turning Object Lock off entirely and only describing COMPLIANCE mode in prose was rejected — it would mean the Terraform never actually encodes the production posture, so there'd be nothing to review, apply, or hand to a future production rollout. Environment-gating keeps the production design real and reviewable while keeping it inert in the environment where it would cause active harm.

---

## Tradeoffs

**`object_lock_enabled` is a ForceNew argument on `aws_s3_bucket`.** If the same bucket/state were ever switched from `dev` to `prod` values, Terraform would destroy and recreate the bucket rather than toggle the setting in place. This is not a practical problem given `dev` and `prod` are expected to be separate deployments, but it means the two tfvars sets are not safely interchangeable against a single live bucket.

---

## Consequences

- `terraform destroy` remains reliable in `dev` no risk of a `security_logs` bucket becoming undeletable due to Object Lock during normal lab teardown.
- The production-grade retention posture (COMPLIANCE mode, 365-day lock, 395-day total object expiration once combined with lifecycle tiering) is fully specified in Terraform and can be tested by using short-term period.
- Before any real production rollout, `prod.tfvars` values must be applied and validated in an environment that is not expected to be destroyed.
