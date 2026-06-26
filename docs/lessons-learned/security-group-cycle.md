# Lesson 3 — Security Group Dependency Cycles in Terraform

## Initial Assumption

Declaring security group rules inline inside the `aws_security_group` resource block is the standard pattern and would work for cross-referencing security groups by ID.

## What Went Wrong

Terraform threw a dependency cycle error during plan:

```
Error: Cycle: aws_security_group.alb, aws_security_group.ecs
```

**Root cause:** SG rules declared inline inside the `aws_security_group` resource create implicit dependencies on whatever SG IDs they reference:

- ALB's inline egress block referencing `ecs.id` makes ALB depend on ECS.
- ECS's inline ingress block referencing `alb.id` makes ECS depend on ALB.

Terraform builds a dependency graph (DAG) before applying. A → B while B → A is not a valid DAG, so the graph walker errors before either resource is created.

## Debugging Path

```
terraform plan → cycle error
→ terraform graph | dot -Tsvg > graph.svg
→ visualized the circular reference between alb-sg and ecs-sg
→ identified inline rules as the cause
→ refactored to standalone rule resources
→ terraform validate - clean
→ terraform plan - no errors
```

> `terraform graph` requires Graphviz: `brew install graphviz` on macOS.

## Fix

Move rules out of the `aws_security_group` resource into standalone `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` resources:

```hcl
# Security group resource — no inline rules
resource "aws_security_group" "ecs" {
  name   = "ecs-sg"
  vpc_id = aws_vpc.main.id
}

# Rule resource — cross-references go here
resource "aws_vpc_security_group_egress_rule" "ecs_to_vpc_endpoint" {
  security_group_id            = aws_security_group.ecs.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.vpc_endpoints.id
}
```

With this pattern, the bare `aws_security_group` resources no longer reference each other — both are created first with no inline rules. The rule resources are created afterward and hold the cross-references. A rule depending on two already-existing SGs is not a cycle — it is two leaf nodes in the graph.

> Standalone security group rule resources require AWS Provider v5.x or later.

## Key Insight

AWS allows bidirectional SG references at the API level. Terraform requires an acyclic dependency graph to plan. These two facts conflict when you declare cross-referencing SG rules inline — the solution is to separate the SG resource from its rules.

The same cycle pattern appears with other resource pairs where each needs the other's ARN (e.g. CloudTrail + S3 bucket policy). If the ARN is predictable, construct it as a `local` value to break the dependency rather than referencing the resource attribute directly.

Always run `terraform validate` after adding or changing resource references — it catches cycle errors before you attempt a plan.
