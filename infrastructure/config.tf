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
  s3_key_prefix  = "config"
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
#config.tf
# Only implement Tagging rules for now, as CIS benchmark and security best practices are managed by securityhub
resource "aws_config_config_rule" "tagging_rule" {
  depends_on = [aws_config_configuration_recorder.config]
  name       = "${var.project_name}-${var.environment}-tagging-rule"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  scope {
    compliance_resource_types = [
      "AWS::EC2::VPC",
      "AWS::EC2::Subnet",
      "AWS::EC2::SecurityGroup",
      "AWS::ElasticLoadBalancingV2::LoadBalancer",
      "AWS::ElasticLoadBalancingV2::Listener",
      "AWS::ElasticLoadBalancingV2::TargetGroup",
      "AWS::ECS::Cluster",
      "AWS::ECS::Service",
      "AWS::RDS::DBInstance",
      "AWS::S3::Bucket",
      "AWS::ECR::Repository",
      "AWS::IAM::Role",
      "AWS::KMS::Key",
      "AWS::Logs::LogGroup",
      "AWS::CloudTrail::Trail",
      "AWS::SNS::Topic",
      "AWS::Lambda::Function",
      "AWS::GuardDuty::Detector",
      "AWS::SecurityHub::Hub"
    ]
  }

  input_parameters = jsonencode({
    tag1Key   = "Project"
    tag1Value = var.project_name
    tag2Key   = "Environment"
    tag2Value = var.environment
    tag3Key   = "ManagedBy"
    tag3Value = var.managed_by
    tag4Key   = "Owner"
    tag4Value = var.owner
  })
}

resource "aws_config_config_rule" "tagging_rule_data_classification" {
  depends_on = [aws_config_configuration_recorder.config]
  name       = "${var.project_name}-${var.environment}-tagging-rule-data-classification"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  scope {
    compliance_resource_types = [
      "AWS::RDS::DBInstance",
      "AWS::S3::Bucket",
      "AWS::ECR::Repository",
      "AWS::EFS::FileSystem",
      "AWS::Logs::LogGroup"
    ]
  }


  input_parameters = jsonencode({
    tag1Key   = "DataClassification"
    tag1Value = var.data_classification
  })
}
