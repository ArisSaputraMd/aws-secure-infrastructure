# =============================================
# rds.tf
# =============================================

# DB Subnet Group — places RDS in private subnets
resource "aws_db_subnet_group" "primary" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
    Project     = var.project_name
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "primary" {
  identifier        = "${var.project_name}-${var.environment}-db"
  engine            = "postgres"
  engine_version    = "16.9"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.primary.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = "default.postgres16"

  multi_az            = false
  publicly_accessible = false
  storage_encrypted   = true
  skip_final_snapshot = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-db"
    Environment = var.environment
    Project     = var.project_name
  }
}
