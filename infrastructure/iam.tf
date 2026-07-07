# =============================================
# IAM Roles and Policies for ECS Tasks
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

# KMS permission for Task role
data "aws_iam_policy_document" "ecs_task_kms_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt"
    ]
    resources = [aws_kms_key.mattermost_files.arn]
  }
}

# ECS Task Execution Role
# Used by ECS to: pull image from ECR, send logs to CloudWatch
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.project_name}-${var.environment}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-execution-role"
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
# Used by the container itself at runtime: read and write to s3

resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.project_name}-${var.environment}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-task-role"
  }
}

resource "aws_iam_role_policy" "ecs_task_kms_policy" {
  name   = "${var.project_name}-${var.environment}-kms-policy"
  role   = aws_iam_role.ecs_task_role.id
  policy = data.aws_iam_policy_document.ecs_task_kms_policy.json
}

# =============================================
# IAM Roles and Policies for VPC Flow Logs
# =============================================

# vpc flow logs iam role 
data "aws_iam_policy_document" "flow_logs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "flow_logs_role" {
  name               = "${var.project_name}-${var.environment}-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-flow-logs-role"
  }
}

data "aws_iam_policy_document" "flow_logs_policy" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = [
      aws_cloudwatch_log_group.vpc.arn,
      "${aws_cloudwatch_log_group.vpc.arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "${var.project_name}-${var.environment}-flow-logs-role-policy"
  role   = aws_iam_role.flow_logs_role.id
  policy = data.aws_iam_policy_document.flow_logs_policy.json
}

# =============================================
# IAM Roles and Policies for AWS Config
# =============================================

data "aws_iam_policy_document" "config_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "config_role" {
  name               = "${var.project_name}-${var.environment}-config-role"
  assume_role_policy = data.aws_iam_policy_document.config_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-config-role"
  }
}

resource "aws_iam_role_policy_attachment" "config_managed_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

data "aws_iam_policy_document" "config_s3_policy" {
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.security_logs.arn}/config/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.security_logs.arn]
  }
}

resource "aws_iam_role_policy" "config_s3_policy" {
  name   = "${var.project_name}-${var.environment}-config-s3-policy"
  role   = aws_iam_role.config_role.id
  policy = data.aws_iam_policy_document.config_s3_policy.json
}

# KMS permission for AWS Config
data "aws_iam_policy_document" "config_kms_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt"
    ]
    resources = [aws_kms_key.security_logs.arn]
  }
}

resource "aws_iam_role_policy" "config_kms_policy" {
  name   = "${var.project_name}-${var.environment}-config-kms-policy"
  role   = aws_iam_role.config_role.id
  policy = data.aws_iam_policy_document.config_kms_policy.json
}

# =============================================
# IAM Roles and Policies for Lambda WAF Auto-Block
# =============================================

resource "aws_iam_role" "waf_autoblock_lambda" {
  name = "${var.project_name}-${var.environment}-waf-autoblock-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "waf_autoblock_permissions" {
  name = "waf-autoblock-permissions"
  role = aws_iam_role.waf_autoblock_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["wafv2:GetIPSet", "wafv2:UpdateIPSet"]
        Resource = aws_wafv2_ip_set.auto_blocked_ips.arn
      },
      {
        Effect   = "Allow"
        Action   = ["wafv2:GetSampledRequests"] # allow Lambda to get the offending Ip
        Resource = aws_wafv2_web_acl.web_acl.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
