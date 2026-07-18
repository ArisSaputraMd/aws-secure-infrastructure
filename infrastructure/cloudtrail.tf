# ------------------------------------------------------------------------------
# CloudTrail — Management Events Trail
# Multi-region, all management events (read + write), global service events.
# Delivers to S3 (long-term, immutable) and CloudWatch Logs (alerting).
# ------------------------------------------------------------------------------
resource "aws_cloudtrail" "management_events" {
  depends_on = [aws_s3_bucket_policy.security_logs_policy]

  name           = "${var.project_name}-${var.environment}-cloudtrail-management-event"
  s3_bucket_name = aws_s3_bucket.security_logs.id
  s3_key_prefix  = "cloudtrail/management-events"
  kms_key_id     = aws_kms_key.security_logs.arn

  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
}

resource "aws_cloudtrail" "data_event" {
  depends_on = [aws_s3_bucket_policy.security_logs_policy]

  name           = "${var.project_name}-${var.environment}-cloudtrail-data-event"
  s3_bucket_name = aws_s3_bucket.security_logs.id
  s3_key_prefix  = "cloudtrail/data-events/mattermost-files"
  kms_key_id     = aws_kms_key.security_logs.arn

  include_global_service_events = false
  is_multi_region_trail         = false
  enable_log_file_validation    = true
  event_selector {
    read_write_type           = "All"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.mattermost_files.arn}/"]
    }
  }

}




