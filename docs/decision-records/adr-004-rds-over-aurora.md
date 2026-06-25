# # ADR-004 — Amazon RDS PostgreSQL over Amazon Aurora PostgreSQL

**Date:** 2026-05
**Status:** Accepted

---

## Context

Mattermost requires a relational database to store application data, including users, channels, messages, configuration, and metadata. The database must provide durability, automated backups, encryption, monitoring, and operational simplicity while supporting a self-hosted deployment model.

AWS provides multiple managed PostgreSQL-compatible database options, including Amazon RDS for PostgreSQL and Amazon Aurora PostgreSQL.

---

## Decision

Use Amazon RDS for PostgreSQL instead of Amazon Aurora PostgreSQL.

---

## Reasoning

| Factor                   | Amazon RDS PostgreSQL        | Amazon Aurora PostgreSQL                   |
| ------------------------ | ---------------------------- | ------------------------------------------ |
| Cost                     | Lower                        | Higher                                     |
| Operational simplicity   | Simple and familiar          | More features to manage                    |
| PostgreSQL compatibility | Native PostgreSQL            | PostgreSQL-compatible                      |
| Performance              | Sufficient for workload      | Higher throughput and scalability          |
| Availability features    | Single-AZ or Multi-AZ        | Built-in multi-AZ storage architecture     |
| Scaling                  | Vertical scaling             | Better horizontal and read scaling         |
| Learning objectives      | Fully satisfies requirements | Provides capabilities beyond project needs |
| Production readiness     | Strong                       | Excellent                                  |

The expected workload is small enough that standard RDS PostgreSQL provides more than sufficient performance capacity. Database utilization is unlikely to approach the thresholds where Aurora's architectural advantages would provide meaningful benefit.

Aurora's strengths become valuable when applications require very high transaction volumes, large-scale read workloads, rapid failover, or aggressive scaling requirements. The Mattermost deployment in this project does not have those characteristics.

Using standard RDS PostgreSQL reduces infrastructure cost while maintaining managed backups, automated patching, encryption at rest, monitoring, and operational simplicity. It also aligns closely with technologies commonly encountered in small and medium-sized organizations, making the implementation easier to understand and maintain.

---

## Tradeoffs

**Reduced scalability:** Aurora can scale read workloads more effectively through Aurora Replicas and its distributed storage architecture. Standard RDS PostgreSQL has more limited scaling options and may require larger instances as demand grows.

**Less resilient storage architecture:** Aurora automatically replicates storage across multiple Availability Zones and can tolerate storage node failures with minimal operational impact. Standard RDS relies on traditional storage architectures and generally requires Multi-AZ deployment for comparable resilience.

**Potential future migration:** If workload growth significantly exceeds expectations, migrating from RDS PostgreSQL to Aurora PostgreSQL may become desirable. While PostgreSQL compatibility simplifies migration, it still introduces operational effort and planning.

These limitations are acceptable because the current workload does not justify Aurora's additional cost or complexity.

---

## Consequences

- Database costs remain lower than an equivalent Aurora deployment.
- PostgreSQL performance remains more than adequate for the expected Mattermost workload.
- Managed backups, monitoring, encryption, and maintenance capabilities remain available.
- The architecture prioritizes cost efficiency and operational simplicity over advanced scalability features.
- Future migration to Aurora remains possible if business requirements evolve toward higher scale or availability targets.
