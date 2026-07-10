# Deployment Runbook

Step-by-step guide to deploy and tear down the stack.

---

## Prerequisites

- Registered domain with DNS delegated to a Route 53 hosted zone
- AWS CLI installed and authenticated (`aws configure` — default region must be `ap-southeast-3`)
- Docker installed and running (Docker Desktop or Docker Engine)
- `tfenv` installed (macOS):

```bash
brew install tfenv
tfenv install 1.15.5
tfenv use 1.15.5
```

---

## 1. Clone and Configure

```bash
git clone https://github.com/ArisSaputraMd/aws-secure-infrastructure.git
cd aws-secure-infrastructure/infrastructure
cp dev.tfvars.example dev.tfvars
```

Edit `dev.tfvars` with your values. Required variables are documented in `dev.tfvars.example`.

---

## 2. Create the ECR Repository and Push the Image

The ECS service pulls its container image from ECR on first launch. The repository must exist and contain an image _before_ the rest of the stack is applied, or the ECS service will fail to place tasks.

Initialize and create only the ECR repository first (do not generate a full-stack plan here — a plan saved now will go stale the moment this targeted apply changes state):

```bash
terraform init
terraform validate
terraform apply -target=aws_ecr_repository.mattermost
```

Move to the repo root to build the image (the Dockerfile lives at repo root, not inside `infrastructure/`):

```bash
cd ..
```

Make sure Docker Desktop is running (open it from Applications, or `open -a Docker` from the terminal, and wait for it to fully start).

Build the image using this repo's `Dockerfile`. Use `--platform linux/amd64` even if you're building on Apple Silicon — the ECS Fargate tasks in this stack run on amd64, and a native ARM build will fail at container startup with an exec format error rather than at build time:

```bash
docker build --platform linux/amd64 -t mattermost:11.9.0 .
```

Authenticate Docker to ECR:

```bash
aws ecr get-login-password --region ap-southeast-3 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-southeast-3.amazonaws.com
```

Tag and push (note the registry hostname is one unbroken string — a line break or stray space here will produce a confusing "requires 2 arguments" error):

```bash
docker tag mattermost:11.9.0 <account-id>.dkr.ecr.ap-southeast-3.amazonaws.com/<repo-name>:11.9.0
docker push <account-id>.dkr.ecr.ap-southeast-3.amazonaws.com/<repo-name>:11.9.0
```

> Get `<account-id>` and `<repo-name>` from `terraform output` (after the
> targeted apply above) or from `dev.tfvars`. The version tag (`11.9.0`)
> must match whatever is currently pinned in the Dockerfile's `FROM` line and task `definition_container` image in [ecs.tf](../../infrastructure/ecs.tf) (keep these in sync if you bump the Mattermost version).

Return to the `infrastructure/` directory before continuing:

```bash
cd infrastructure
```

---

## 3. Store the Database Password in SSM

This parameter are intentionally not managed by Terraform (see [ADR-002](/docs/decision-records/adr-002-ssm-parameter-store-over-secrets-manager.md)) and must exist before the full stack apply in Step 4, or the affected resource will fail to read it.

```bash
aws ssm put-parameter \
  --name "/<environment>/<project_name>/database/mattermost/password" \
  --type "SecureString" \
  --value "<your-password>" \
  --region ap-southeast-3
```

> The DSN is constructed by Terraform in `ssm.tf` and stored as a second SSM parameter. It does not need to be created manually.

---

## 4. Apply the Rest of the Stack

Generate and apply a fresh plan now that the ECR repo exists and the image has been pushed:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

## 5. SNS email confirmation required.

After Step 4's apply creates the SNS subscriptions, AWS sends a confirmation email to `security_email` and `root_owner_email` addresses you fill in your `.tfvars` (root email only recheive alert related to root account security). Alerts will not be delivered until each recipient clicks the confirmation link. Check both inboxes (including spam) after applying, and confirm before relying on this stack for real alerting.

---

## 6. Verify

After a successful apply, confirm the stack is working:

```bash
terraform output mattermost_url
```

Open the URL in a browser and confirm Mattermost loads over HTTPS. If the ECS task has not reached `RUNNING` yet, wait for 1–2 minutes and try again.

---

## 7. Tear Down

```bash
terraform destroy -auto-approve
```

> The stack is designed as a deploy-and-destroy lab. Tear it down when not actively in use to avoid idle cost.
>
> The ECR repository and the image pushed in Step 2 are destroyed along with everything else. You will need to rebuild and repush on the next deploy unless you change the repository to `force_delete = false` and manage image retention separately (not currently how this project is configured).

---

## Notes

### CloudTrail S3 bucket object lock

Object lock behavior is controlled by `logs_bucket_object_lock` in `dev.tfvars`:

| Environment | Value   | Behavior                                                                                        |
| ----------- | ------- | ----------------------------------------------------------------------------------------------- |
| `dev`       | `false` | No object lock — `terraform destroy` completes cleanly                                          |
| `prod`      | `true`  | COMPLIANCE mode, 365-day retention — objects cannot be deleted by anyone during the lock period |

In `dev`, `terraform destroy` works normally. In `prod`, the CloudTrail S3 bucket **cannot be destroyed** until all objects' lock periods expire — this is intentional. COMPLIANCE mode ensures audit logs cannot be tampered with even under credential compromise. Plan accordingly before running `destroy` against a prod environment.

### SSM parameters persist after destroy

SSM parameters are not managed by Terraform and will remain after `terraform destroy`. Delete them manually if needed:

```bash
aws ssm delete-parameter \
  --name "/<environment>/<project_name>/database/mattermost/password" \
  --region ap-southeast-3

aws ssm delete-parameter \
  --name "/<environment>/<project_name>/database/mattermost/db_dsn" \
  --region ap-southeast-3
```
