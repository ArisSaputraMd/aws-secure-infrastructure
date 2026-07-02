# =============================================
# ecs.tf
# =============================================
# CloudWatch Log Group — stores Mattermost container logs
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 30

  tags = {
    Name               = "${var.project_name}-${var.environment}-ecs-logs"
    DataClassification = "internal"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  tags = {
    Name = "${var.project_name}-${var.environment}-cluster"
  }
}

# ECS Task Definition — defines the Mattermost container
resource "aws_ecs_task_definition" "mattermost" {
  family                   = "${var.project_name}-${var.environment}-mattermost"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "mattermost"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/mattermost/mattermost-team-edition:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8065
          hostPort      = 8065
          protocol      = "tcp"
        }
      ]

      secrets = [
        {
          name      = "MM_SQLSETTINGS_DATASOURCE"
          valueFrom = aws_ssm_parameter.db_dsn.arn
        }
      ]

      environment = [
        {
          name  = "MM_SERVICESETTINGS_SITEURL"
          value = "https://${var.domain_name}"
        },
        # S3 file storage
        {
          name  = "MM_FILESETTINGS_DRIVERNAME"
          value = "amazons3"
        },
        {
          name  = "MM_FILESETTINGS_AMAZONS3BUCKET"
          value = aws_s3_bucket.mattermost_files.id
        },
        {
          name  = "MM_FILESETTINGS_AMAZONS3REGION"
          value = var.aws_region
        },
        {
          name  = "MM_FILESETTINGS_AMAZONS3SSL"
          value = "true"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "mattermost"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.environment}-mattermost-task"
  }
}

# ECS Service — keeps the Mattermost task running
resource "aws_ecs_service" "mattermost" {
  name            = "${var.project_name}-${var.environment}-mattermost"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mattermost.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs.arn
    container_name   = "mattermost"
    container_port   = 8065
  }

  depends_on = [aws_lb_listener.https]

  tags = {
    Name = "${var.project_name}-${var.environment}-mattermost-service"
  }
}
