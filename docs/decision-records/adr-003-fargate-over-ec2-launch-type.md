# ADR-003 — Fargate over EC2 Launch Type

**Date:** 2026-05
**Status:** Accepted

---

## Context

Mattermost is deployed as a Docker container on ECS. This deployment targets a medium-sized organization that prioritizes operational simplicity and cost efficiency without compromising on security posture. The platform is self-hosted to retain data control and avoid per-seat SaaS costs at scale.

ECS supports two launch types for running containers: Fargate (serverless compute) and EC2 (self-managed instances). The choice between them has meaningful implications for operational overhead, cost model, and control.

---

## Decision

Use ECS Fargate as the container launch type.

---

## Reasoning

| Factor               | Fargate                                         | EC2 Launch Type                                                      |
| -------------------- | ----------------------------------------------- | -------------------------------------------------------------------- |
| Compute cost         | Higher (convenience premium)                    | Lower with good bin-packing + RI/Savings Plans                       |
| Operational overhead | Very low — no instance management               | Higher — AMIs, patching, ECS agent, capacity planning                |
| Deployment speed     | Fast — task definition update triggers deploy   | Slower — instance provisioning adds to cycle time                    |
| Scaling              | Fast — no cluster capacity to pre-provision     | Medium — cluster capacity must be managed separately                 |
| Security isolation   | Strong — each task gets its own kernel boundary | Weaker — tasks on the same host share the kernel                     |
| Best fit             | Variable/bursty loads, small-to-medium teams    | Steady high-utilization workloads, large-scale cost-sensitive setups |

Fargate eliminates the operational surface area of EC2-based ECS: no AMI management, no OS patching, no ECS agent updates, no capacity planning, no bin-packing, and no Spot instance handling. This directly reduces engineering time — which, for a small team, frequently costs more per hour than the Fargate compute premium itself.

Total cost of ownership (TCO) favors Fargate at this scale even when raw compute cost does not.

---

## Tradeoffs

**Cost at scale:** Fargate's convenience premium becomes a liability at sustained high utilization with predictable workloads. At large scale with well-packed EC2 instances and Reserved Instance or Savings Plans pricing, EC2 can be 20–40% cheaper.

At very large scale with dedicated platform engineering, EC2 or EKS with Karpenter often wins on cost. Fargate wins at smaller scale or early-stage deployments where operational simplicity has a real dollar value.

**Control surface:** Fargate does not support custom kernel configuration, host-level tooling, or privileged container access. For workloads with
compliance requirements that mandate kernel-level visibility or custom OS configuration, EC2 would be the appropriate choice. Mattermost has no such requirement.

---

## Consequences

- No cost or toil for instance maintenance — patching, AMI updates, ECS agent upgrades, and capacity planning are fully abstracted.
- Compute cost is higher than an equivalent well-packed EC2 deployment with Reserved Instances over the long run.
- No custom kernel access or host-level tooling — acceptable for a Mattermost workload with no such requirements.
