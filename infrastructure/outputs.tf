output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}
output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.application_load_balancer.dns_name
}

output "mattermost_url" {
  description = "Mattermost application URL"
  value       = "https://${var.domain_name}"
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.primary.address
  sensitive   = true
}

output "security_log_bucket_name" {
  description = "Security Logs bucket name"
  value       = aws_s3_bucket.security_logs.bucket
}

output "security_log_bucket_arn" {
  description = "Security Logs Bucket ARN"
  value       = aws_s3_bucket.security_logs.arn
  sensitive   = true
}

output "mattermost_bucket_name" {
  description = "Mattermost bucket name"
  value       = aws_s3_bucket.mattermost_files.bucket
}

output "mattermost_bucket_arn" {
  description = "Mattermost bucket ARN"
  value       = aws_s3_bucket.mattermost_files.arn
  sensitive   = true
}

output "vpc_flow_log_arn" {
  description = "Vpc flow logs arn"
  value       = aws_flow_log.vpc.arn
}

output "config_recorder" {
  description = "AWS Config configurations recorder"
  value       = aws_config_configuration_recorder.config.id
}

output "config_channel" {
  description = "AWS Config Channel"
  value       = aws_config_delivery_channel.config.id
}

output "config_recorder_status" {
  description = "AWS Config recorder status"
  value       = aws_config_configuration_recorder_status.config.id
}

output "config_role" {
  description = "Role for AWS config arn"
  value       = aws_iam_role.config_role.arn
}

output "config_kms" {
  description = "kms key for security logs bucket"
  value       = aws_s3_bucket.security_logs.arn
}
