# ------------------------------------------------------------------------------
# KMS for APP
# ------------------------------------------------------------------------------
resource "aws_kms_key" "mattermost_files" {
  description             = "CMK for encrypting mattermost files in s3"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-mattermost-files-key"
  }
}

resource "aws_kms_alias" "mattermost_files" {
  name          = "alias/${var.project_name}-${var.environment}-mattermost-files-key"
  target_key_id = aws_kms_key.mattermost_files.id
}

data "aws_iam_policy_document" "mattermost_files_kms_policy" {

  # Required: prevent aws_kms_key_policy replaces the default policy and lose all access to the key permanently.
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowECSTaskRole"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.ecs_task_role.arn]
    }
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt",
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key_policy" "mattermost_files" {
  key_id = aws_kms_key.mattermost_files.id
  policy = data.aws_iam_policy_document.mattermost_files_kms_policy.json
}

# ------------------------------------------------------------------------------
# KMS For RDS
# ------------------------------------------------------------------------------
resource "aws_kms_key" "rds" {
  description             = "CMK for encrypting RDS instances"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-key"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-${var.environment}-rds-key"
  target_key_id = aws_kms_key.rds.id
}


data "aws_iam_policy_document" "rds_kms_policy" {

  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_kms_key_policy" "rds" {
  key_id = aws_kms_key.rds.id
  policy = data.aws_iam_policy_document.rds_kms_policy.json
}

# ------------------------------------------------------------------------------
# KMS for Security logs 
# ------------------------------------------------------------------------------
resource "aws_kms_key" "security_logs" {
  description             = "CMK for encrypting logs — S3"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-security-logs-key"
  }
}

resource "aws_kms_alias" "security_logs" {
  name          = "alias/${var.project_name}-${var.environment}-security-logs-key"
  target_key_id = aws_kms_key.security_logs.id
}

data "aws_iam_policy_document" "kms_policy" {

  # Required: prevent aws_kms_key_policy replaces the default policy and lose all access to the key permanently.
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
  # CloudTrail: only the actions actually needed for log delivery.
  # EncryptionContext condition scopes this to CloudTrail ARNs in this account only 
  statement {
    sid    = "EnableCloudTrailPermissions"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt",
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"]
    }
  }

  #AWS Configs 
  statement {
    sid    = "EnableConfigPermissions"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # AWS WAFv2: only the actions actually needed for log delivery.
  statement {
    sid    = "EnableWAFv2Permissions"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["wafv2.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # AWS Flow-Logs: log delivery.
  statement {
    sid    = "EnableFlowLogsPermissions"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["flow-logs.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key_policy" "security_logs" {
  key_id = aws_kms_key.security_logs.id
  policy = data.aws_iam_policy_document.kms_policy.json
}
