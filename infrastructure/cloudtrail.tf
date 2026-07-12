# ------------------------------------------------------------------------------
# CloudTrail — Management Events Trail
# Multi-region, all management events (read + write), global service events.
# Delivers to S3 (long-term, immutable) and CloudWatch Logs (alerting).
# ------------------------------------------------------------------------------
resource "aws_cloudtrail" "management_events" {
  depends_on = [aws_s3_bucket_policy.security_logs_policy]

  name           = "${var.project_name}-${var.environment}-cloudtrail"
  s3_bucket_name = aws_s3_bucket.security_logs.id
  s3_key_prefix  = "cloudtrail/management-events"
  kms_key_id     = aws_kms_key.security_logs.arn

  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
}





