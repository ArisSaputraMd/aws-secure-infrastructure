# Commented out by default to avoid per-scan cost on every
# deploy/destroy cycle. Un-comment to enable AWS Inspector2 for the account.

# resource "aws_inspector2_enabler" "this" {
#   account_ids    = [data.aws_caller_identity.current.account_id]
#   resource_types = ["ECR", "LAMBDA", "LAMBDA_CODE"]
# }
