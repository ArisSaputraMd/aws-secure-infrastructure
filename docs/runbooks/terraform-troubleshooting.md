# Terraform Troubleshooting Runbook

A structured approach to diagnosing and resolving Terraform errors.

> There are four potential types of issues you can experience with Terraform: language, state, core, and provider errors. Work through them in that order.

Official reference: [HashiCorp Troubleshooting Workflow](https://developer.hashicorp.com/terraform/tutorials/configuration-language/troubleshooting-workflow)

---

## Workflow

```
language/state/core/provider → research → thesis → test → validate → apply/rollback → document
```

---

## Step 1 — Identify the error type

| Type     | Description                                     | First action                                              |
| -------- | ----------------------------------------------- | --------------------------------------------------------- |
| Language | HCL syntax or expression error                  | `terraform validate`                                      |
| State    | State file out of sync with real infrastructure | `terraform refresh` or manual state edit                  |
| Core     | Bug in Terraform itself                         | Check GitHub issues, upgrade version                      |
| Provider | AWS API error or resource misconfiguration      | Enable debug logging, check provider docs and AWS console |

---

## Step 2 — Always validate first

```bash
terraform validate
```

Run after every code change. Catches syntax errors and type mismatches before a plan.

---

## Step 3 — Plan before applying

```bash
terraform plan -out=tfplan
```

Review the diff carefully. Look for unexpected destroys or replacements before proceeding.

---

## Step 4 — Enable debug logging for provider errors

For AWS API errors and provider-level failures, enable Terraform debug logging:

```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log
terraform apply
```

The log captures the full AWS API request and response, including error codes and messages that don't surface in normal output. Disable after debugging:

```bash
unset TF_LOG
unset TF_LOG_PATH
```

---

## Step 5 — Check dependency graph on cycle errors

Requires Graphviz (`brew install graphviz` on macOS):

```bash
terraform graph | dot -Tsvg > graph.svg
```

Visualize the dependency graph to identify circular references. See the [Security Group Cycle lesson](../lessons-learned/security-group-cycle.md) for a real example from this project.

---

## Step 6 — Check CloudWatch logs for ECS runtime errors

For ECS task failures, the error chain is:

```
ECS console (stoppedReason) → describe-tasks → CloudWatch log stream
```

```bash
aws ecs describe-tasks \
  --cluster <cluster-name> \
  --tasks <task-id> \
  --query "tasks[].stoppedReason" \
  --region ap-southeast-3
```

---

## Common Patterns

### Dependency cycle

**Symptom:** `Error: Cycle: aws_security_group.a, aws_security_group.b`

**Cause:** Inline SG rules referencing each other create a circular dependency in the Terraform graph.

**Fix:** Move rules to standalone `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` resources.

See [Security Group Cycle](../lessons-learned/security-group-cycle.md) for the full write-up.

---

### ARN cycle (CloudTrail + S3 bucket policy)

**Symptom:** Two resources each require the other's ARN in their configuration.

**Fix:** If the ARN is predictable (e.g. S3 bucket ARN follows `arn:aws:s3:::<bucket-name>`), construct it as a `local` value to break the dependency rather than referencing the resource attribute directly.

---

### ECS task exits immediately

**Symptom:** Task reaches `RUNNING` briefly then exits with `EssentialContainerExited`.

**Debugging path:** ECS console → `stoppedReason` → `describe-tasks` → CloudWatch log stream.

Common causes: IAM permission error before container start (fix: Task Execution Role policy), or a malformed connection string (fix: `urlencode()` on the password in the DSN). See [ECS Roles & Secrets](../lessons-learned/ecs-roles-secrets.md) and [URI Encoding DSN](../lessons-learned/uri-encoding-dsn.md).

---

## Targeted Apply

Use `-target` to apply or plan a single resource without touching the rest of the state. Useful for isolating failures during debugging:

```bash
terraform plan -target=aws_ecs_service.mattermost
terraform apply -target=aws_ecs_service.mattermost
```

> Use `-target` only for debugging. Do not rely on it for normal deployments — it can leave the state partially applied and inconsistent with your configuration.

---

## Rollback

If `apply` fails partway through:

1. Check `terraform show` to see what was created.
2. Fix the configuration error.
3. Re-run `terraform plan` and `terraform apply`.

Terraform doesn't blindly recreate everything every time you run terraform apply — re-applying will only act on what differs from the current state. Use `terraform destroy` only if you want to tear the full environment down.

If state is inconsistent with real infrastructure (e.g. a resource was deleted outside Terraform), use `terraform state rm <resource>` to remove it from state before re-applying, or `terraform import` to bring an existing resource back under management.
