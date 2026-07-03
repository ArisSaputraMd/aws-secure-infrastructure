# Phase 2 Overview

**Status:** In-Progress | `dev` environment | deploy-and-destroy lab model

---

## Scope

Phase 2 establishes the infrastructure improvment by implementing AWS Well-architected tool to fill the gap from foundational infrastructure. The project will not cover all Pillars but it suffecient for medium-sized organization that prioritizes operational simplicity and cost efficiency without compromising on security posture..

Design decisions throughout this project such as security design, reliability, high availability, disaster recovery strategy, etc. are made within deployment context constraints. See the [decision records](../decision-records/) for the reasoning behind each major choice.

### 6 pillars delivered

| Pillars                                                  | Decision rationale                                                                                                                                                                                               |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Operational Exelence](pillar-1-operational-excelence)   | Build using Terraform (IaC), centralize monitoring using CloudWatch, guardrail using IAM access analyzer and AWS Config                                                                                          |
| [Security](pillar-2-security)                            | Implementing the latest CIS benchmark (v5.0) and FSBP, hardening access control by implemnting least-privilage principal, using security services to protect, detect, monitor, investigate and incident response |
| [Reliability](pillar-3-reliability)                      |                                                                                                                                                                                                                  |
| [Peformance Efficiency](pillar-4-performance-efficiency) |                                                                                                                                                                                                                  |
| [Cost Optimization](pillar-5-cost-optimization)          |                                                                                                                                                                                                                  |
| [Sustainbility](pillar-6-sustainbility)                  |                                                                                                                                                                                                                  |
