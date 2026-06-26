# Lessons Learned

Real issues hit during deployment and how they were debugged — not a clean retelling, the actual troubleshooting path.

Each entry documents the initial assumption, what went wrong, the debugging path taken, the fix, and the key takeaway.

---

## Index

|     | Issue                                                                     | File                                               |
| --- | ------------------------------------------------------------------------- | -------------------------------------------------- |
| 1   | ECS Task Role vs. Task Execution Role — SSM permission in the wrong place | [ecs-roles-secrets.md](ecs-roles-secrets.md)       |
| 2   | Reserved characters in connection strings — URI encoding the DB password  | [uri-encoding-dsn.md](uri-encoding-dsn.md)         |
| 3   | Security group dependency cycles in Terraform                             | [security-group-cycle.md](security-group-cycle.md) |

---

## Patterns

Two distinct debugging patterns came up during Phase 1.

**Layered runtime failures (Lessons 1 and 2):** The ECS task had to get past the IAM error before the DSN parse error was visible. Each fix exposed the next failure — the errors couldn't be seen simultaneously. Working through one layer at a time is the only approach; trying to diagnose everything at once doesn't work when later errors are hidden behind earlier ones.

**Build-time graph failures (Lesson 3):** The security group cycle had to be resolved before Terraform could create any resources at all. This is a different category — not a runtime failure you debug by reading logs, but a planning failure you resolve by restructuring resource dependencies. Terraform's dependency graph is validated before any apply; if the graph isn't acyclic, nothing gets created.
