# ADR-014 — Single AWS Account (Multi-Account via AWS Organizations Deferred)

**Date:** 2026-07-13
**Status:** Accepted

---

## Context

AWS's own well-architected guidance recommends a multi-account structure via AWS Organizations for production workloads. A dedicated management account, a logging account, a security-tooling account, and separate accounts per environment (dev, staging, prod), tied together with Service Control Policies (SCPs) and centralized aggregation for GuardDuty/Security Hub/Config. This structure exists specifically to isolate blast radius. A compromise or misconfiguration in one account cannot directly reach resources or credentials in another.

This project is a solo-built portfolio piece, run on a deploy-and-destroy lab model, in a single region, by one person with no existing AWS Organization, no team to distribute account ownership across, and a defined timeline to reach job-readiness. Every account in an Organization carries its own baseline setup cost, IAM identity strategy, cross-account roles, centralized logging pipelines, SCP authoring. None of which is optional if the isolation the pattern exists for is to actually hold.

A decision was needed on whether to build the multi-account structure now, as part of demonstrating Well-Architected Security pillar maturity, or to defer it.

---

## Decision

Deploy this project in a single AWS account. Defer multi-account structure via AWS Organizations.

---

## Reasoning

| Factor                                                                                                                | Multi-account (AWS Organizations)                                                                                          | Single account (chosen)                                                           |
| --------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Blast radius isolation                                                                                                | Strong, compromise in one account can't directly reach another                                                             | Weak, all resources share one trust boundary                                      |
| Setup cost (IAM, cross-account roles, SCPs, log aggregation)                                                          | High, nontrivial even before any workload resources exist                                                                  | None, IAM stays within one account's boundary                                     |
| Fit for solo, single-region, deploy-and-destroy lab                                                                   | Poor, isolation benefits assume persistent, team-operated environments                                                     | Good, matches the project's actual operating model                                |
| Ongoing operational overhead                                                                                          | Higher, account-per-environment means duplicated baseline resources                                                        | Lower, one set of baseline resources to maintain                                  |
| Demonstrates core Security pillar controls (IAM least-privilege, Config, GuardDuty, Security Hub, detection/response) | Yes, plus account isolation on top                                                                                         | Yes, all of these controls exist and function identically at single-account scope |
| Realistic for stated career-transition timeline                                                                       | Adds weeks of AWS Organizations/SCP setup work with lower learning-per-hour return than deepening Security pillar controls | Keeps focus on the controls that matter most for target Tier 1–3 roles            |

The controls that actually demonstrate security engineering competency like least-privilege IAM, detective controls (GuardDuty, Security Hub, Config, EventBridge alerting), encryption, network segmentation, WAF, incident response process, all function identically whether the account is one or many. Multi-account adds a structural isolation layer on top of those controls, it does not replace or substitute for them. Given the project's actual constraints (solo operator, lab cadence, fixed timeline), the isolation benefit doesn't pay for its setup and maintenance cost here, while the underlying controls it would sit on top of are already fully built and documented.

---

## Tradeoffs

**Larger blast radius.** A compromised IAM credential or misconfigured resource in this account has a wider reach than it would in a properly isolated multi-account structure there's no organizational boundary stopping lateral movement from, say, a compromised ECS task role to touching logging or security-tooling resources, beyond IAM least-privilege itself.

**No SCP-level guardrails.** Service Control Policies enforce account-wide restrictions (e.g., "no resource in this account may ever be created outside `ap-southeast-3`") that IAM alone can't replicate, since IAM policies are attached to principals, not applied account-wide regardless of principal. This project relies entirely on IAM and Config rules for governance, with no SCP backstop.

**Centralized logging isn't structurally separated from the workload.** In a proper multi-account setup, the logging account is a separate trust boundary from the account generating the logs, a compromise of the workload account doesn't automatically grant access to tamper with its own audit trail from outside. Here, `security_logs` lives in the same account as everything it's logging; the trail's integrity depends entirely on IAM permissions and (in `prod`) Object Lock, not on account-level separation.

**Not representative of how the target role will actually operate.** Tier 3 (Cloud Security Engineer) roles at any organization with mature AWS usage will almost certainly involve multi-account environments. This project doesn't give hands-on exposure to that reality. Organizations, SCPs, and cross-account IAM remain a genuine gap, not just an intentionally deferred nice-to-have.

---

## Consequences

- All resources, logging, and security tooling in this project share a single AWS account trust boundary.
- IAM least-privilege and Config rules are the sole governance mechanism; there is no SCP-level enforcement.
- `security_logs` bucket integrity rests on IAM permissions and, in `prod`, Object Lock, not on being in a separate account from the workload it logs.
- Migration to a multi-account structure remains a known, explicitly deferred extension (not implemented, and not currently scheduled) since it falls outside this project's remaining Phase 2/3 scope.
- Multi-account/AWS Organizations experience should be treated as a standing skill gap for the Tier 3 target role, to be closed through a separate exercise or on-the-job exposure rather than retrofitted into this project.
