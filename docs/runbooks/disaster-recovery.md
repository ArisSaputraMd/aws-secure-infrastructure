# Disaster Recovery Runbook

> **Status:** Placeholder — to be completed in Phase 2 (Reliability pillar).

---

## Scope

This runbook will cover recovery procedures for the following failure scenarios:

- ECS task crash loop or failed deployment
- RDS instance failure or data loss
- CloudTrail log gap or delivery failure
- Full environment loss (accidental `terraform destroy`)

---

## Phase 1 Recovery (Current)

The Phase 1 stack uses a deploy-and-destroy lab model. There is no standby environment.

**To recover from a failed state:**

1. Run `terraform destroy -auto-approve` to clear any partial resources.
2. Verify SSM parameters still exist (they are not managed by Terraform).
3. Re-run the full [Deployment Runbook](deployment-runbook.md).

**RDS:** No automated backups are configured in Phase 1. Single-AZ with no Multi-AZ standby. Data loss in a failure scenario is accepted for a lab environment.

---

## Planned for Phase 2

- AWS Backup policy for automated RDS snapshots
- Multi-AZ RDS upgrade
- ECS service auto-recovery configuration
- Documented RTO/RPO targets per component
