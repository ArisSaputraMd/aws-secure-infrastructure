# =============================================
# Security Groups
# =============================================

# Security Group — VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
  description = "Allow HTTPS traffic from private subnets to AWS VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}
resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_ingress" {
  description                  = "Allow HTTPS from ECS Tasks"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.vpc_endpoints.id
  referenced_security_group_id = aws_security_group.ecs.id
}

# Security Group — ALB
# Allows HTTP and HTTPS from the internet
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Allow HTTP and HTTPS traffic from the internet"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  description       = "Allow HTTP from internet"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.alb.id
}


resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  description       = "Allow HTTPS from internet"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  description                  = "Allow outbound traffic to ECS"
  from_port                    = 8065
  to_port                      = 8065
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ecs.id
}



# Security Group — ECS
# Allows traffic only from the ALB — not directly from the internet
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-${var.environment}-ecs-sg"
  description = "Allow traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_http" {
  description                  = "Allow HTTP from ALB"
  from_port                    = 8065
  to_port                      = 8065
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_rds" {
  description                  = "Allow outbound traffic to RDS"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.rds.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_vpc_endpoints" {
  description                  = "Allow outbound traffic to VPC Endpoints"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.vpc_endpoints.id
}


# Security Group — RDS
# Allows PostgreSQL only from ECS — nothing else
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Allow PostgreSQL from ECS only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_postgresql" {
  description                  = "Allow PostgreSQL from ECS"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ecs.id
}

