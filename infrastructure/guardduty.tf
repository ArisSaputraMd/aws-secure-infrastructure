# =============================================
# Guardduty
# use matadata from vpc flow log to detect anomalies
# =============================================

resource "aws_guardduty_detector" "detector" {
  enable = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-guardduty-detector"
    Project     = "${var.project_name}"
    Environment = "${var.environment}"
  }
}
