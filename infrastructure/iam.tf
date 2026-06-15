# =============================================
# IAM Roles and Pilicies for ECS Tasks
# =============================================

# Fetch current AWS account ID dynamically
data "aws_caller_identity" "current" {}

# Shared Assume Role Policy
# Allows ECS Tasks to assume IAM roles
data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# SSM Policy — read DB credentials at runtime
data "aws_iam_policy_document" "ecs_task_ssm_policy" {
  statement {
    effect  = "Allow"
    actions = ["ssm:GetParameters"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.environment}/${var.project_name}/*"
    ]
  }
}

# ECS Task Execution Role
# Used by ECS to: pull image from ECR, send logs to CloudWatch
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.project_name}-${var.environment}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-execution-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_ssm_policy" {
  name   = "${var.project_name}-${var.environment}-ssm-read-policy"
  role   = aws_iam_role.ecs_task_execution_role.id
  policy = data.aws_iam_policy_document.ecs_task_ssm_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}



# ECS Task Role
# Used by the container itself at runtime: read DB password from SSM
resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.project_name}-${var.environment}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-task-role"
    Environment = var.environment
    Project     = var.project_name
  }
}
resource "aws_iam_role_policy" "ecs_task_ssm_policy" {
  name   = "${var.project_name}-${var.environment}-ssm-read-policy"
  role   = aws_iam_role.ecs_task_role.id
  policy = data.aws_iam_policy_document.ecs_task_ssm_policy.json
}
