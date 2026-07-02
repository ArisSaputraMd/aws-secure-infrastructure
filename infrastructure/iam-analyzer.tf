# =============================================
# Security Alerting — EventBridge + SNS
# Based on CIS AWS Foundations Benchmark
# =============================================

resource "aws_accessanalyzer_analyzer" "external_access" {
  analyzer_name = "${var.project_name}-${var.environment}-external-accessanalyzer"
  type          = "ACCOUNT"
}
