# =============================================
# AWS Config
# note:
# Starting the Configuration Recorder requires a delivery channel (while delivery 
# channel creation requires Configuration Recorder). This is why
# aws_config_configuration_recorder_status is a separate resource.
# =============================================

resource "aws_config_delivery_channel" "config" {
  depends_on = [aws_config_configuration_recorder.config]

  name           = "${var.project_name}-${var.environment}-config"
  s3_bucket_name = aws_s3_bucket.security_logs.bucket
  s3_key_prefix  = "config/"
  s3_kms_key_arn = aws_kms_key.security_logs.arn

}
resource "aws_config_configuration_recorder" "config" {
  name     = "${var.project_name}-${var.environment}-config"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  recording_mode {
    recording_frequency = "CONTINUOUS"
  }
}

resource "aws_config_configuration_recorder_status" "config" {
  name       = aws_config_configuration_recorder.config.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.config]
}
