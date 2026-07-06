# # =============================================
# # SecurityHub - 
# # Classic Cloud Security Posture Management and SH v2 for seamless and intelligent aggregation and better usability
# # Pending - apply after upgrade account into paid plan
# # =============================================

# resource "aws_securityhub_account" "cspm" {
#   enable_default_standards = false
#   depends_on               = [aws_guardduty_detector.detector]
# }
# resource "aws_securityhub_account_v2" "main" {}

# resource "aws_securityhub_standards_subscription" "fsbp" {
#   depends_on    = [aws_securityhub_account.cspm]
#   standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
# }
# # Follow the latest AWS CIS Benchmark - v5.0
# # CIS v5.0.0 required Terraform AWS provider version ~> 6.0
# resource "aws_securityhub_standards_subscription" "cis_fb" {
#   depends_on    = [aws_securityhub_account.cspm]
#   standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/5.0.0"
# }

# # Pull guardduty findings
# resource "aws_securityhub_product_subscription" "guardduty" {
#   depends_on  = [aws_securityhub_account.cspm]
#   product_arn = "arn:aws:securityhub:${var.aws_region}::product/aws/guardduty"
# }

# resource "aws_securityhub_product_subscription" "inspector" {
#   depends_on  = [aws_securityhub_account.cspm]
#   product_arn = "arn:aws:securityhub:${var.aws_region}::product/aws/inspector"
# }
