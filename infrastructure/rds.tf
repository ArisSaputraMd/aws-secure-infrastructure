# =============================================
# rds.tf
# =============================================
# CloudWatch Log Group — stores rds logs
resource "aws_cloudwatch_log_group" "rds" {
  name              = "/aws/rds/instance/${var.project_name}-${var.environment}-db/postgresql"
  retention_in_days = 30

  tags = {
    Name               = "${var.project_name}-${var.environment}-rds-logs"
    DataClassification = "internal"
  }
}

# DB Subnet Group — places RDS in private subnets
resource "aws_db_subnet_group" "primary" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "primary" {
  identifier                      = "${var.project_name}-${var.environment}-db"
  engine                          = "postgres"
  engine_version                  = "16.9"
  instance_class                  = "db.t3.micro"
  allocated_storage               = 20
  storage_type                    = "gp2"
  enabled_cloudwatch_logs_exports = ["postgresql"]

  db_name  = var.db_name
  username = var.db_username
  password = data.aws_ssm_parameter.db_password.value
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.primary.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = "default.postgres16"

  multi_az            = false
  publicly_accessible = false
  storage_encrypted   = true
  kms_key_id          = aws_kms_key.rds.arn
  skip_final_snapshot = true

  tags = {
    Name               = "${var.project_name}-${var.environment}-db"
    DataClassification = "Confidential"
  }
}

