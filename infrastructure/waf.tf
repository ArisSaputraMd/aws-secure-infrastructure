# =============================================
# Note:
# when you use the aws_wafv2_web_acl_rule or 
# aws_wafv2_web_acl_rule_group_association resources with this 
# Web ACL, you must add lifecycle { ignore_changes = [rule] } 
# to this resource to prevent configuration drift. Those resources 
# manage the Web ACL's rules outside of this resource's direct management.
# =============================================

resource "aws_wafv2_web_acl" "web_acl" {
  name  = "${var.project_name}-${var.environment}-web-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-metric"
    sampled_requests_enabled   = true
  }

  # Prevent Terraform from managing inline rules (configuration drift)
  lifecycle {
    ignore_changes = [rule]
  }
}

# AWS Managed Rules

resource "aws_wafv2_web_acl_rule" "common_rule" {
  name        = "common-rule"
  priority    = 6
  web_acl_arn = aws_wafv2_web_acl.web_acl.arn

  override_action {
    none {}
  }

  statement {
    managed_rule_group_statement {
      name        = "AWSManagedRulesCommonRuleSet"
      vendor_name = "AWS"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "common-metric"
    sampled_requests_enabled   = true
  }
}


resource "aws_wafv2_web_acl_rule" "known_bad_inputs_rule" {
  name        = "known-bad-inputs-rule"
  priority    = 4
  web_acl_arn = aws_wafv2_web_acl.web_acl.arn

  override_action {
    none {}
  }

  statement {
    managed_rule_group_statement {
      name        = "AWSManagedRulesKnownBadInputsRuleSet"
      vendor_name = "AWS"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "known-bad-inputs-metric"
    sampled_requests_enabled   = true
  }
}


resource "aws_wafv2_web_acl_rule" "sql_injection_rule" {
  name        = "sql-injection-rule"
  priority    = 5
  web_acl_arn = aws_wafv2_web_acl.web_acl.arn

  override_action {
    none {}
  }

  statement {
    managed_rule_group_statement {
      name        = "AWSManagedRulesSQLiRuleSet"
      vendor_name = "AWS"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "sql-injection-metric"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_rule" "ip_reputation_rule" {
  name        = "ip-reputation-rule"
  priority    = 7
  web_acl_arn = aws_wafv2_web_acl.web_acl.arn

  override_action {
    none {}
  }

  statement {
    managed_rule_group_statement {
      name        = "AWSManagedRulesAmazonIpReputationList"
      vendor_name = "AWS"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ip-reputation-metric"
    sampled_requests_enabled   = true
  }
}

# Custom rules for rate limiting (configured in count mode to log requests that exceed the limit)

# Global Rate Limit Rule to catch large floods
resource "aws_wafv2_web_acl_rule" "global_rate_limit" {
  name        = "global-rate-limit"
  priority    = 3
  web_acl_arn = aws_wafv2_web_acl.web_acl.arn

  action {
    block {}
  }

  statement {
    rate_based_statement {
      limit              = 4000
      aggregate_key_type = "IP"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "global-rate-limit-metric"
    sampled_requests_enabled   = true
  }
}

# Rate limit for Login endpoint
resource "aws_wafv2_web_acl_rule" "login_rate_limit" {
  name        = "login-rate-limit"
  priority    = 1
  web_acl_arn = aws_wafv2_web_acl.web_acl.arn

  action {
    block {}
  }

  statement {
    rate_based_statement {
      limit              = 200
      aggregate_key_type = "IP"

      scope_down_statement {
        regex_match_statement {
          field_to_match {
            uri_path {}
          }

          regex_string = "^/api/v4/(users/login|auth)"

          text_transformation {
            priority = 0
            type     = "NONE"
          }
        }
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "login-rate-limit-metric"
    sampled_requests_enabled   = true
  }
}

# rate-limit for File Uploads and Posts endpoints
resource "aws_wafv2_web_acl_rule" "files_posts_rate_limit" {
  name        = "files-posts-rate-limit"
  priority    = 2
  web_acl_arn = aws_wafv2_web_acl.web_acl.arn

  action {
    block {}
  }

  statement {
    rate_based_statement {
      limit              = 800
      aggregate_key_type = "IP"

      scope_down_statement {
        regex_match_statement {
          field_to_match {
            uri_path {}
          }

          # Matches: /api/v4/files... and /api/v4/posts...
          regex_string = "^/api/v4/(files|posts)"

          text_transformation {
            priority = 0
            type     = "NONE"
          }
        }
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "files-posts-rate-limit-metric"
    sampled_requests_enabled   = true
  }
}

# Associate the WAF Web ACL with the Application Load Balancer
resource "aws_wafv2_web_acl_association" "alb_association" {
  resource_arn = aws_lb.application_load_balancer.arn
  web_acl_arn  = aws_wafv2_web_acl.web_acl.arn
}

# Configure WAF logging to an S3 bucket
resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
  log_destination_configs = [aws_s3_bucket.security_logs.arn]
  resource_arn            = aws_wafv2_web_acl.web_acl.arn

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "COUNT"
        }
      }
      requirement = "MEETS_ALL"
    }

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      requirement = "MEETS_ANY"
    }
  }
}
