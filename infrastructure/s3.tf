# ==============================================================================
# App Bucket - Mattermost file storage 
# ==============================================================================

resource "aws_s3_bucket" "mattermost_files" {

  bucket        = "${var.project_name}-${var.environment}-mattermost-files-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.mattermost_files_force_destroy

  tags = {
    Name               = "${var.project_name}-${var.environment}-mattermost-files"
    DataClassification = "Confidential"
  }
}

# -----------------------------------------------------------------------------
# Bucket Policy
# ------------------------------------------------------------------------------

# Allow ECS task role to accsess S3
data "aws_iam_policy_document" "ecs_task_s3" {
  statement {
    sid    = "AllowECSTaskRoleAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.ecs_task_role.arn]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.mattermost_files.arn,
      "${aws_s3_bucket.mattermost_files.arn}/*"
    ]
  }
}


resource "aws_s3_bucket_policy" "mattermost_files_policy" {
  bucket = aws_s3_bucket.mattermost_files.id
  policy = data.aws_iam_policy_document.ecs_task_s3.json
}

# Versioning enabled for recovery of accidentally deleted files
resource "aws_s3_bucket_versioning" "mattermost-files" {
  bucket = aws_s3_bucket.mattermost_files.id
  versioning_configuration {
    status = "Enabled"
  }
}


# SSE-KMS with CMK. bucket_key_enabled reduces KMS API calls (and cost)
# by caching the data key at the S3 layer rather than calling KMS per object.
resource "aws_s3_bucket_server_side_encryption_configuration" "mattermost-files" {
  bucket = aws_s3_bucket.mattermost_files.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.mattermost_files.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Block Public Access
# Belt-and-suspenders on top of the bucket policy. Prevents any future policy change from accidentally making logs public.
resource "aws_s3_bucket_public_access_block" "mattermost_files" {
  bucket = aws_s3_bucket.mattermost_files.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Lifecycle Configuration
resource "aws_s3_bucket_intelligent_tiering_configuration" "mattermost_files" {
  bucket = aws_s3_bucket.mattermost_files.id
  name   = "MattermostFiles"

  status = "Enabled"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}

# version-expiration lifecycle (Old version will expire after 180 days)
resource "aws_s3_bucket_lifecycle_configuration" "mattermost_files_versions" {
  depends_on = [aws_s3_bucket_versioning.mattermost-files]
  bucket     = aws_s3_bucket.mattermost_files.id

  rule {
    status = "Enabled"
    id     = "mattermost"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 180
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }
  }
}

# ==============================================================================
# Logs bucket
# - force_destroy is controlled via a variable. In production, this must be false to prevent Terraform from deleting
#   non-empty S3 buckets and their contents during destroy operations.
# - Object lock and retention are controled via variable, dev env are set to false as default.
# ==============================================================================
resource "aws_s3_bucket" "security_logs" {
  depends_on = [aws_kms_key.security_logs]

  bucket              = "${var.project_name}-${var.environment}-security-logs-v2"
  force_destroy       = var.logs_bucket_force_destroy
  object_lock_enabled = var.logs_bucket_object_lock

  tags = {
    Name               = "${var.project_name}-${var.environment}-security-logs"
    DataClassification = "Restricted"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "security_logs" {
  bucket = aws_s3_bucket.security_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.security_logs.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Versioning - Required for object lock and state visibility.
resource "aws_s3_bucket_versioning" "security_logs" {
  depends_on = [aws_s3_bucket.security_logs]
  bucket     = aws_s3_bucket.security_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "security_logs" {
  bucket = aws_s3_bucket.security_logs.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Object Lock for prod env — set logs_bucket_object_lock = true in .tfvars to enable it
resource "aws_s3_bucket_object_lock_configuration" "security_logs" {
  count      = var.logs_bucket_object_lock ? 1 : 0
  depends_on = [aws_s3_bucket_versioning.security_logs]
  bucket     = aws_s3_bucket.security_logs.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.bucket_compliance_days
    }
  }
}

# ------------------------------------------------------------------------------
# Security logs Bucket Policy - Central security logs
# ------------------------------------------------------------------------------
data "aws_region" "current" {}

# construct arn to prevent cycle dependency
locals {
  management_trail_arn = "arn:aws:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${var.project_name}-${var.environment}-cloudtrail-management-event"
  data_trail_arn       = "arn:aws:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${var.project_name}-${var.environment}-cloudtrail-data-event"
}

locals {
  flow_logs_arn = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
}

data "aws_iam_policy_document" "security_logs_policy" {
  # Deny insecure transport (http) to S3 bucket
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.security_logs.arn,
      "${aws_s3_bucket.security_logs.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # CloudTrail Read (pre-flight check before delivery)
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.security_logs.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.management_trail_arn, local.data_trail_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # CloudTrail management event Write Permissions (log delivery)
  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.security_logs.arn}/cloudtrail/management-events/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.management_trail_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }


  # CloudTrail data event Write Permissions
  statement {
    sid    = "AWSCloudTrailDataWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.security_logs.arn}/cloudtrail/data-events/mattermost-files/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.data_trail_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # Config read permission
  statement {
    sid    = "AWSConfigCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.security_logs.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # Config write permission
  statement {
    sid    = "AWSConfigWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.security_logs.arn}/config/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # - VPC Flow logs permission
  statement {
    sid    = "AWSFlowLogsAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.security_logs.arn]


    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [local.flow_logs_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AWSFlowLogsWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions = [
      "s3:PutObject"
    ]
    resources = ["${aws_s3_bucket.security_logs.arn}/flow-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [local.flow_logs_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "security_logs_policy" {
  depends_on = [data.aws_iam_policy_document.security_logs_policy]
  bucket     = aws_s3_bucket.security_logs.id
  policy     = data.aws_iam_policy_document.security_logs_policy.json
}


# Lifecycle Configuration (auto delete, 30 days after compliance mode expire for operational buffer like audit etc.)
resource "aws_s3_bucket_lifecycle_configuration" "security_logs" {
  depends_on = [aws_s3_bucket_versioning.security_logs]
  bucket     = aws_s3_bucket.security_logs.id

  rule {
    id     = "cloudtrail-log-tiering"
    status = "Enabled"
    expiration {
      days = 395
    }

    filter {
      prefix = "cloudtrail/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
  }

  rule {
    id     = "config-tiering"
    status = "Enabled"
    expiration {
      days = 395
    }

    filter {
      prefix = "config"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
  }

  rule {
    id     = "flow-logs-tiering"
    status = "Enabled"
    expiration {
      days = 395
    }

    filter {
      prefix = "flow-logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
  }
}

# ==============================================================================
# ELB Access Logs bucket - SSE-S3
# - force_destroy is controlled via a variable. In production, this must be false to prevent Terraform from deleting
#   non-empty S3 buckets and their contents during destroy operations.
# - Object lock and retention are controled via variable, dev env are set to false as default.
# ==============================================================================
resource "aws_s3_bucket" "elb_logs" {
  bucket              = "${var.project_name}-${var.environment}-elb-logs"
  force_destroy       = var.logs_bucket_force_destroy
  object_lock_enabled = var.logs_bucket_object_lock

  tags = {
    Name               = "${var.project_name}-${var.environment}-elb-logs"
    DataClassification = "Restricted"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "elb_logs" {
  bucket = aws_s3_bucket.elb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning - Required for object lock and state visibility.
resource "aws_s3_bucket_versioning" "elb_logs" {
  depends_on = [aws_s3_bucket.elb_logs]
  bucket     = aws_s3_bucket.elb_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "elb_logs" {
  bucket = aws_s3_bucket.elb_logs.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Object Lock for prod env — set logs_bucket_object_lock = true in .tfvars to enable it
resource "aws_s3_bucket_object_lock_configuration" "elb_logs" {
  count      = var.logs_bucket_object_lock ? 1 : 0
  depends_on = [aws_s3_bucket_versioning.elb_logs]
  bucket     = aws_s3_bucket.elb_logs.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.bucket_compliance_days
    }
  }
}

locals {
  elb_logs_arn = "arn:aws:elasticloadbalancing:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:loadbalancer/*"
}

data "aws_iam_policy_document" "elb_logs_policy" {
  # Deny insecure transport (http) to S3 bucket
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.elb_logs.arn,
      "${aws_s3_bucket.elb_logs.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # ALB access logs write permission
  statement {
    sid    = "AWSAlbLogsWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
    actions = [
      "s3:PutObject"
    ]
    resources = ["${aws_s3_bucket.elb_logs.arn}/elb/alb-accesslogs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [local.elb_logs_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "elb_logs_policy" {
  depends_on = [data.aws_iam_policy_document.elb_logs_policy]
  bucket     = aws_s3_bucket.elb_logs.id
  policy     = data.aws_iam_policy_document.elb_logs_policy.json
}


# Lifecycle Configuration (auto delete, 30 days after compliance mode expire for operational buffer like audit etc.)
resource "aws_s3_bucket_lifecycle_configuration" "elb_logs" {
  depends_on = [aws_s3_bucket_versioning.elb_logs]
  bucket     = aws_s3_bucket.elb_logs.id

  rule {
    id     = "alb-access-log-tiering"
    status = "Enabled"
    expiration {
      days = 395
    }

    filter {
      prefix = "elb/alb-accesslogs"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
  }
}

# ==============================================================================
# Athena query output bucket - SSE-S3
# ==============================================================================
resource "aws_s3_bucket" "athena_output" {
  bucket              = "${var.project_name}-${var.environment}-athena-output"
  force_destroy       = true
  object_lock_enabled = false

  tags = {
    Name               = "${var.project_name}-${var.environment}-athena-output"
    DataClassification = "Internal"
    Owner              = "security-team"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_output" {
  bucket = aws_s3_bucket.athena_output.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "athena_output" {
  bucket = aws_s3_bucket.athena_output.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_output" {
  bucket = aws_s3_bucket.athena_output.id

  rule {
    id     = "auto-delete-after-7-days"
    status = "Enabled"
    expiration {
      days = 7
    }
  }
}

data "aws_iam_policy_document" "athena_bucket_policy" {
  # Deny insecure transport (http) to S3 bucket
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.athena_output.arn,
      "${aws_s3_bucket.athena_output.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "athena_bucket_policy" {
  bucket = aws_s3_bucket.athena_output.id
  policy = data.aws_iam_policy_document.athena_bucket_policy.json
}

#iam.tf
resource "aws_iam_user_group_membership" "team" {
  user = aws_iam_user.analyst_demo.name
  groups = [
    aws_iam_group.sec_analyst.name
  ]
}

# iam group
resource "aws_iam_group" "sec_analyst" {
  name = "security-analyst-group"
}
data "aws_iam_policy_document" "sec_analyst_group_policy" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    resources = [
      aws_iam_role.sec_analyst_role.arn
    ]
  }
}
resource "aws_iam_group_policy" "sec_analyst_group_policy" {
  name   = "${var.project_name}-${var.environment}-sec-analyst-group-policy"
  group  = aws_iam_group.sec_analyst.id
  policy = data.aws_iam_policy_document.sec_analyst_group_policy.json
}
# iam user
resource "aws_iam_user" "analyst_demo" {
  name = "analyst_demo"
}

#
data "aws_iam_policy_document" "sec_analyst_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.analyst_demo.arn]
    }
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}
# Security analytics role
resource "aws_iam_role" "sec_analyst_role" {
  name               = "${var.project_name}-${var.environment}-sec-analyst-role"
  assume_role_policy = data.aws_iam_policy_document.sec_analyst_assume_role_policy.json

  tags = {
    Name = "${var.project_name}-${var.environment}-sec-analyst-role"
  }
}


data "aws_iam_policy_document" "sec_analyst_role_policy" {

  # Permission to read security_log bucket (cloudtrail, flow-logs, configs)
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
    ]

    resources = [
      aws_s3_bucket.security_logs.arn,
      "${aws_s3_bucket.security_logs.arn}/*"
    ]
  }

  # Permission to read elb_logs bucket (alb access logs)
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
    ]

    resources = [
      aws_s3_bucket.elb_logs.arn,
      "${aws_s3_bucket.elb_logs.arn}/*"
    ]
  }

  # permission to read/write athena output bucket
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      aws_s3_bucket.athena_output.arn,
      "${aws_s3_bucket.athena_output.arn}/*"
    ]
  }

  # KMS permission to access security_logs
  statement {
    sid       = "EnableCloudTrailDescribeKey"
    effect    = "Allow"
    actions   = ["kms:DescribeKey"]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt",
    ]
    resources = [aws_kms_key.security_logs.arn]
  }

  # Permission to execute athena
  statement {
    effect = "Allow"
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:StopQueryExecution",
      "athena:GetWorkGroup"
    ]

    resources = [aws_athena_workgroup.security_analytics.arn]
  }

  # permission to read glue database
  statement {
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartitions"
    ]

    resources = [
      aws_glue_catalog_database.security_analytics.arn,
      "${aws_glue_catalog_database.security_analytics.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "sec_analyst_policy" {
  name   = "${var.project_name}-${var.environment}-sec-analyst-policy"
  role   = aws_iam_role.sec_analyst_role.id
  policy = data.aws_iam_policy_document.sec_analyst_role_policy.json
}
