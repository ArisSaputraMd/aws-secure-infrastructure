# ==============================================================================
# Mattermost file storage 
# Key properties:
#   - KMS-encrypted (CMK, bucket key enabled for cost saving)
#   - Public access fully blocked
#   - versioning - noncurrent expire after 90 days
#   - Lifecycle: intelligent tiering
# ==============================================================================


# ------------------------------------------------------------------------------
# KMS Key
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

# ------------------------------------------------------------------------------
# KMS Key Policy
# ------------------------------------------------------------------------------
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
# Bucket
# force_destroy is controlled via a variable. In production, this must be false to prevent Terraform from deleting
# non-empty S3 buckets and their contents during destroy operations.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "mattermost_files" {

  bucket        = "${var.project_name}-${var.environment}-mattermost-files-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.mattermost_files_force_destroy

  tags = {
    Name               = "${var.project_name}-${var.environment}-mattermost-files"
    DataClassification = "Confidential"
  }
}

# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Versioning
# recomended to recovery of accidentally deleted files
# old version will be expires after 3 month
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "mattermost-files" {
  bucket = aws_s3_bucket.mattermost_files.id
  versioning_configuration {
    status = "Enabled"
  }
}


# ------------------------------------------------------------------------------
# KMS Encryption
# SSE-KMS with CMK. bucket_key_enabled reduces KMS API calls (and cost)
# by caching the data key at the S3 layer rather than calling KMS per object.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Block Public Access
# Belt-and-suspenders on top of the bucket policy. Prevents any future policy
# change from accidentally making logs public.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "mattermost_files" {
  bucket = aws_s3_bucket.mattermost_files.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

#------------------------------------------------------------------------------
# Lifecycle Configuration
# Old version will expire after 90 days
# Timeline:
#   Day  0  → STANDARD        (hot, immediately accessible)
#   Day 90  → Intelligent Tiering  - not accessed file
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_intelligent_tiering_configuration" "mattermost_files" {
  bucket = aws_s3_bucket.mattermost_files.id
  name   = "MattermostFiles"

  status = "Enabled"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}


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

