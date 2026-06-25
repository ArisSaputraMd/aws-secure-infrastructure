# ADR-008 — Single-AZ RDS for Phase 1 Dev Environment

**Date:** 2026-05
**Status:** Accepted

---

## Context

Amazon RDS supports both Single-AZ and Multi-AZ deployments. Multi-AZ improves availability by maintaining a synchronous standby replica in a separate Availability Zone and automatically failing over during infrastructure outages.

This additional resilience comes with significantly higher cost — approximately double the instance cost of a Single-AZ deployment.

This deployment targets a medium-sized organization that prioritizes operational simplicity and cost efficiency without compromising on security posture.

Phase 1 establishes the core infrastructure in a dev environment. Availability architecture is revisited in Phase 2 as part of the Well-Architected Reliability pillar implementation.

---

## Decision

Use a Single-AZ RDS PostgreSQL deployment for the Phase 1 dev environment.

---

## Reasoning

| Factor                   | Single-AZ                           | Multi-AZ                         |
| ------------------------ | ----------------------------------- | -------------------------------- |
| Database cost            | Lower                               | ~2x (standby instance required)  |
| Availability             | Single Availability Zone            | Automatic failover across AZs    |
| Operational complexity   | Simple                              | Slightly higher                  |
| Recovery from AZ failure | Manual restore or snapshot recovery | Automatic failover               |
| Phase 1 fit              | High                                | Cost not justified at this stage |

Multi-AZ would increase resilience against Availability Zone failures, which are rare events and outside the scope of Phase 1 objectives. The cost doubles without providing meaningful benefit in a dev environment with no uptime SLA.

Single-AZ RDS provides all database functionality required by Mattermost while preserving budget for higher-priority controls: encryption, backup retention, centralized logging, CloudTrail auditing, EventBridge monitoring, SNS alerting, and IAM least privilege.

---

## Tradeoffs

**Reduced availability:** A Single-AZ deployment introduces a single point of failure at the Availability Zone level. If the underlying AZ experiences an outage, the database becomes unavailable until AWS restores service or a recovery procedure is performed.

**Higher RTO:** Recovery may require restoring from an automated backup or redeploying infrastructure, resulting in a significantly longer Recovery Time Objective compared to Multi-AZ automatic failover.

**Not appropriate for production workloads:** Organizations with customer-facing services, uptime SLAs, or formal availability requirements would require Multi-AZ to minimize downtime risk.

For Phase 1, these limitations are acceptable because the environment is a dev deployment with no uptime requirements.

---

## Consequences

- RDS cost remains significantly lower than an equivalent Multi-AZ deployment.
- Database availability is limited to a single Availability Zone.
- Encryption, monitoring, and managed backup operations remain available.
- A deliberate cost-versus-availability tradeoff is accepted for Phase 1.
- This decision is superseded by ADR-010 in Phase 2, which implements Multi-AZ as part of the Well-Architected Reliability pillar.
