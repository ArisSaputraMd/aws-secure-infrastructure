# ------------------------------------------------------------------------------
# CloudTrail — Management Events Trail
# Multi-region, all management events (read + write), global service events.
# Delivers to S3 (long-term, immutable) and CloudWatch Logs (alerting).
# ------------------------------------------------------------------------------
resource "aws_cloudtrail" "management_events" {
  depends_on = [aws_s3_bucket_policy.security_logs_policy]

  name           = "${var.project_name}-${var.environment}-cloudtrail"
  s3_bucket_name = aws_s3_bucket.security_logs.id
  s3_key_prefix  = "cloudtrail/management-events"
  kms_key_id     = aws_kms_key.security_logs.arn

  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
}


# ------------------------------------------------------------------------------
# S3 Bucket Policy — CloudTrail Write Permissions
# Grants CloudTrail service principal:
#   - GetBucketAcl (pre-flight check before delivery)
#   - PutObject    (log delivery)
# Both statements are scoped to this trail's ARN via aws:SourceArn.
# ------------------------------------------------------------------------------
data "aws_region" "current" {}

locals {
  cloudtrail_arn = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.project_name}-${var.environment}-cloudtrail"
}

data "aws_iam_policy_document" "cloudtrail" {
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
      values   = [local.cloudtrail_arn]
    }
  }

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
      values   = [local.cloudtrail_arn]
    }
  }
}


# ==============================================================================
# kms.tf
# Customer-managed KMS key (CMK) for encrypting CloudTrail logs in S3.
# Using CMK over AWS-managed key gives: key rotation control, fine-grained
# policy, cross-service grant scoping.
# ==============================================================================


# ------------------------------------------------------------------------------
# KMS Key
# ------------------------------------------------------------------------------
resource "aws_kms_key" "security_logs" {
  description             = "CMK for encrypting CloudTrail logs — S3 and CloudWatch Logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-security-logs-key"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_kms_alias" "security_logs" {
  name          = "alias/${var.project_name}-${var.environment}-security-logs-key"
  target_key_id = aws_kms_key.security_logs.id
}


# ------------------------------------------------------------------------------
# KMS Key Policy
# ------------------------------------------------------------------------------

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
  # EncryptionContext condition scopes this to CloudTrail ARNs in this account only —
  # prevents other services from using this key under the CloudTrail principal.
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
}

resource "aws_kms_key_policy" "security_logs" {
  key_id = aws_kms_key.security_logs.id
  policy = data.aws_iam_policy_document.kms_policy.json
}

# ==============================================================================
# s3.tf
# Security log lake — centralised immutable store for CloudTrail logs.
# Key properties:
#   - KMS-encrypted (CMK, bucket key enabled for cost saving)
#   - Public access fully blocked
#   - Object lock in COMPLIANCE mode — logs cannot be deleted for 365 days,
#     even by the root account. Satisfies NIST 800-53 AU-9 and PCI-DSS 10.5.
#   - Lifecycle: transitions to cheaper tiers; NO expiration before lock expires
# ==============================================================================


# ------------------------------------------------------------------------------
# Bucket
# force_destroy is controlled via a variable. In production, this must be false to prevent Terraform from deleting
# non-empty S3 buckets and their contents during destroy operations.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "security_logs" {
  depends_on = [aws_kms_key.security_logs]

  bucket              = "${var.project_name}-${var.environment}-security-logs"
  force_destroy       = var.logs_bucket_force_destroy
  object_lock_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-security-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}


# ------------------------------------------------------------------------------
# Versioning
# Required for object lock. Declared explicitly for state visibility.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "security_logs" {
  depends_on = [aws_s3_bucket.security_logs]
  bucket     = aws_s3_bucket.security_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}


# ------------------------------------------------------------------------------
# KMS Encryption
# SSE-KMS with CMK. bucket_key_enabled reduces KMS API calls (and cost)
# by caching the data key at the S3 layer rather than calling KMS per object.
# ------------------------------------------------------------------------------
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


# ------------------------------------------------------------------------------
# Block Public Access
# Belt-and-suspenders on top of the bucket policy. Prevents any future policy
# change from accidentally making logs public.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "security_logs" {
  bucket = aws_s3_bucket.security_logs.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}


# ------------------------------------------------------------------------------
# Bucket Policy — CloudTrail write permissions
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "security_logs_policy" {
  depends_on = [data.aws_iam_policy_document.cloudtrail]
  bucket     = aws_s3_bucket.security_logs.id
  policy     = data.aws_iam_policy_document.cloudtrail.json
}


# ------------------------------------------------------------------------------
# Object Lock — COMPLIANCE mode, 365 days
# Must be applied after versioning is enabled.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_object_lock_configuration" "security_logs" {
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
# Lifecycle Configuration
# Transitions logs through cheaper storage tiers as they age.
#
# Timeline:
#   Day  0  → STANDARD        (hot, immediately accessible)
#   Day 30  → STANDARD_IA     (infrequent access, same latency)
#   Day 90  → GLACIER_IR      (instant retrieval, ~60% cheaper than IA)
#   Day 365 → DEEP_ARCHIVE    (bulk retrieval 12h, ~80% cheaper than Glacier IR)
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "security_logs" {
  depends_on = [aws_s3_bucket_versioning.security_logs]
  bucket     = aws_s3_bucket.security_logs.id

  rule {
    id     = "cloudtrail-log-tiering"
    status = "Enabled"

    filter {
      prefix = "cloudtrail/management-events"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

  }
}

# ==============================================================================
# variables.tf
# ==============================================================================
variable "logs_bucket_force_destroy" {
  description = <<-EOT
    Whether to force-delete all objects in the security logs bucket on destroy.
    Must be false in prod — COMPLIANCE object lock will block force-destroy anyway,
    but keeping this false makes the intent explicit and prevents accidents.
  EOT
  type        = bool
  default     = false
}



variable "bucket_compliance_days" {
  type        = number
  description = "Compliance retention for logs bucket"
  default     = 365
}
