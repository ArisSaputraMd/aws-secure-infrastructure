# Deployment Runbook

Step-by-step guide to deploy and tear down the stack.

---

## Prerequisites

- Registered domain with DNS delegated to a Route 53 hosted zone
- AWS CLI installed and authenticated (`aws configure` — default region must be `ap-southeast-3`)
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
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values. Required variables are documented in `terraform.tfvars.example`.

---

## 2. Store the DB Password in SSM

Before applying, manually create the DB password parameter in SSM as a `SecureString`:

```bash
aws ssm put-parameter \
  --name "/<environment>/<project_name>/database/mattermost/password" \
  --type "SecureString" \
  --value "<your-password>" \
  --region ap-southeast-3
```

Replace `<environment>`, `<project_name>`, and `<your-password>` with your values from `terraform.tfvars`. The region must match your deployment region.

> The DSN is constructed by Terraform in `ssm.tf` and stored as a second SSM parameter. It does not need to be created manually.

---

## 3. Apply

```bash
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

---

## 4. Verify

After a successful apply, confirm the stack is working:

```bash
terraform output mattermost_url
```

Open the URL in a browser and confirm Mattermost loads over HTTPS. If the ECS task has not reached `RUNNING` yet, wait for 1–2 minutes and try again.

---

## 5. Tear Down

```bash
terraform destroy -auto-approve
```

> The stack is designed as a deploy-and-destroy lab. Tear it down when not actively in use to avoid idle cost.

---

## Notes

### CloudTrail S3 bucket object lock

Object lock behavior is controlled by `logs_bucket_object_lock` in `terraform.tfvars`:

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
