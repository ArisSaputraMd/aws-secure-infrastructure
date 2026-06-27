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
  value       = aws_lb.frontend.dns_name
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

output "security_log_bucket" {
  description = "Security Logs Bucket ARN"
  value       = aws_s3_bucket.security_logs.arn
  sensitive   = true
}

output "mattermost_bucket_ids" {
  description = "Mattermost file storage id"
  value       = aws_s3_bucket.mattermost_files.id
}

output "mattermost_bucket_arn" {
  description = "Mattermost bucket ARN"
  value       = aws_s3_bucket.mattermost_files.arn
  sensitive   = true
}
