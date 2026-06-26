# Lesson 2 — Reserved Characters in Connection Strings (URI Encoding)

## Initial Assumption

Once the IAM issue was resolved and the container started, the database connection would work — the DSN was constructed correctly in Terraform and the parameter value was retrievable from SSM.

## What Went Wrong

The container started but exited immediately with `EssentialContainerExited`, exit code 1.

The PostgreSQL DSN couldn't be parsed correctly. The database password contained `#`, a reserved URI character that marks the start of a URI fragment, so the parser stopped reading the password at `#` and interpreted the remainder as URI syntax instead of credential data. Terraform generated the string correctly, but the resulting connection URI was invalid because reserved characters in the password weren't URL-encoded before being interpolated into the DSN.

## Debugging Path

```
ECS console - task stoppedReason - EssentialContainerExited
→ describe-tasks → CloudWatch log stream
→ application error: could not parse DSN
→ identified # in password as unencoded reserved character
```

```bash
aws ecs describe-tasks \
  --cluster <cluster-name> \
  --tasks <task-id> \
  --query "tasks[].stoppedReason" \
  --region ap-southeast-3
```

## Fix

Wrap the password with `urlencode()` inside `local.db_dsn`:

```hcl
locals {
  db_dsn = "postgres://${var.db_username}:${urlencode(data.aws_ssm_parameter.db_password.value)}@${aws_db_instance.primary.address}:5432/${var.db_name}?sslmode=require"
}
```

`urlencode()` is a built-in Terraform function, no external dependency needed.

## Key Insight

Always URL-encode passwords when interpolating them into connection string URIs. Common reserved characters that break URI parsing: `#`, `@`, `:`, `/`, `?`, `&`, `=`, `+`, `%`.

This issue is invisible during `terraform plan` — the DSN string looks correct in the output. It only surfaces at runtime when the application tries to parse the connection string.
