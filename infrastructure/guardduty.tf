# # =============================================
# # Guardduty
# # use matadata from vpc flow log to detect anomalies
# # pending - apply after upgrade account into paid plan
# # =============================================

# resource "aws_guardduty_detector" "detector" {
#   enable = true

#   tags = {
#     Name               = "${var.project_name}-${var.environment}-guardduty-detector"
#   }
# }
