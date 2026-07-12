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
  priority    = 7
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
  priority    = 5
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
  priority    = 6
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
  priority    = 8
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
  priority    = 4
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
  priority    = 2
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
  priority    = 3
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

# stores WAF BLOCK/COUNT actions only. (ALLOW dropped by logging_filter)
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "aws-waf-logs-blocked-logs"
  retention_in_days = 30

  tags = {
    Name               = "${var.project_name}-${var.environment}-waf-logs"
    DataClassification = "internal"
  }
}

resource "aws_cloudwatch_log_resource_policy" "waf_logs" {
  policy_document = data.aws_iam_policy_document.cw_log_waf.json
  policy_name     = "${var.project_name}-${var.environment}-cw-webacl-policy"
}

data "aws_iam_policy_document" "cw_log_waf" {
  statement {
    sid    = "AWSWafv2Write"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.waf_logs.arn}:*"]
    condition {
      test     = "ArnLike"
      values   = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"]
      variable = "aws:SourceArn"
    }
    condition {
      test     = "StringEquals"
      values   = [tostring(data.aws_caller_identity.current.account_id)]
      variable = "aws:SourceAccount"
    }
  }
}

# Configure WAF logging to cloudwatch logs group
resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.web_acl.arn

  depends_on = [aws_cloudwatch_log_resource_policy.waf_logs]

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

# WAF automation 
resource "aws_wafv2_ip_set" "auto_blocked_ips" {
  name               = "${var.project_name}-${var.environment}-auto-blocked"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = []

  lifecycle {
    ignore_changes = [addresses] # Lambda manages the list at runtime
  }
}

resource "aws_wafv2_web_acl_rule" "auto_block_rule" {
  name        = "auto-blocked-ips"
  priority    = 0
  web_acl_arn = aws_wafv2_web_acl.web_acl.arn

  action {
    block {}
  }

  statement {
    ip_set_reference_statement {
      arn = aws_wafv2_ip_set.auto_blocked_ips.arn
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "auto-block-metric"
    sampled_requests_enabled   = true
  }
}


resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "${var.project_name}-${var.environment}-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 100 # start with 50 blocked requests in 5 minutes, might be to hight but safer. adjust as needed.
  alarm_description   = "Triggers when WAF blocks more than threshold requests in 5 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.web_acl.name
    Region = var.aws_region
    Rule   = "ALL"
  }

  alarm_actions = [aws_sns_topic.waf_alerts.arn]
  # ok_actions    = [aws_sns_topic.waf_alerts.arn]  #notify when it recovers is defered, security team will check the alarm and the blocked IPs and decide if it is ok to recover or not. - threshold is untested.
}

data "aws_iam_policy_document" "sns_topic_waf_alerts" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    resources = [
      aws_sns_topic.waf_alerts.arn
    ]
  }
}

resource "aws_sns_topic" "waf_alerts" {
  name = "waf-alerts"
}

resource "aws_sns_topic_policy" "waf_alerts" {
  arn    = aws_sns_topic.waf_alerts.arn
  policy = data.aws_iam_policy_document.sns_topic_waf_alerts.json
}

resource "aws_sns_topic_subscription" "waf_alerts_security" {
  topic_arn = aws_sns_topic.waf_alerts.arn
  protocol  = "email"
  endpoint  = var.security_email
}

resource "aws_sns_topic_subscription" "lambda_trigger" {
  topic_arn = aws_sns_topic.waf_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.waf_autoblock.arn
}

