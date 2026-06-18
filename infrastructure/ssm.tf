data "aws_ssm_parameter" "db_password" {
  name            = "/${var.environment}/${var.project_name}/database/mattermost/password"
  with_decryption = true
}

locals {
  db_dsn = "postgres://${var.db_username}:${urlencode(data.aws_ssm_parameter.db_password.value)}@${aws_db_instance.primary.address}:5432/${var.db_name}?sslmode=require"
}

resource "aws_ssm_parameter" "db_dsn" {
  name        = "/${var.environment}/${var.project_name}/database/mattermost/db_dsn"
  description = "DSN for Mattermost RDS instance"
  type        = "SecureString"
  value       = local.db_dsn

  overwrite = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-dsn"
    Environment = var.environment
    Project     = var.project_name
  }
}
