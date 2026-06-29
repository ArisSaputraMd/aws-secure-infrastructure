# =============================================
# Security Alerting — EventBridge + SNS
# Based on CIS AWS Foundations Benchmark
# =============================================
#
# Alert routing:
#  security team  - all topics
#  root owner     - root_usage topic only
#
# Email recipients are stored in SSM (not hardcoded).
# =============================================


# -----------------------------------------------------------------
# SSM — Alert recipients
# -----------------------------------------------------------------

data "aws_ssm_parameter" "security_email" {
  name = "/${var.environment}/${var.project_name}/alerts/security-email"
}

data "aws_ssm_parameter" "root_owner_email" {
  name = "/${var.environment}/${var.project_name}/alerts/root-owner-email"
}


# -----------------------------------------------------------------
# Shared: SNS publish policy for EventBridge
# -----------------------------------------------------------------

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [
      aws_sns_topic.cloudtrail_changes.arn,
      aws_sns_topic.console_login_no_mfa.arn,
      aws_sns_topic.iam_warning.arn,
      aws_sns_topic.kms_key_changes.arn,
      aws_sns_topic.root_usage.arn,
      aws_sns_topic.nacl_changes.arn,
      aws_sns_topic.sg_changes.arn
    ]
  }
}

# -----------------------------------------------------------------
# rule 1: IAM privilege escalation — CIS 4.4 / 4.6
# Indicates a user or role is being granted elevated permissions.
# PassRole is particularly high-signal — it allows one principal
# to delegate a role's permissions to a service or other principal.
# -----------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "iam_warning" {
  name        = "iam-warning"
  description = "Detects IAM actions that indicate privilege escalation"

  event_pattern = jsonencode({
    "source" : ["aws.iam"],
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail" : {
      "eventName" : [
        "CreateUser",
        "AttachUserPolicy",
        "PutRolePolicy",
        "AttachRolePolicy",
        "PassRole",
        "UpdateAssumeRolePolicy"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "iam_warning_sns" {
  rule      = aws_cloudwatch_event_rule.iam_warning.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.iam_warning.arn

  input_transformer {
    input_paths = {
      event   = "$.detail.eventName",
      time    = "$.detail.eventTime",
      user    = "$.detail.userIdentity.userName",
      account = "$.detail.userIdentity.accountId",
      source  = "$.detail.sourceIPAddress",
      console = "$.detail.sessionCredentialFromConsole"
    }
    input_template = "\"ALERT: IAM changes has been detected!.\\n\\nSeverity: HIGH!. Detail:\\n\\nEvent: <event>\\nTime: <time>\\nUser: <user>\\nAccount: <account>\\nSource IP: <source>\\nStatus: <status>\\nConsole LogIn: <console>\\n\\nImmediate action required:\\n\\nPlease confirm if the <event> is legitimate. Thanks\""

  }

}

resource "aws_sns_topic" "iam_warning" {
  name = "iam-warning-alert"
}

resource "aws_sns_topic_policy" "iam_warning" {
  arn    = aws_sns_topic.iam_warning.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

resource "aws_sns_topic_subscription" "iam_warning_security" {
  topic_arn = aws_sns_topic.iam_warning.arn
  protocol  = "email"
  endpoint  = data.aws_ssm_parameter.security_email.value
}

# -----------------------------------------------------------------
# rule 2: Root account usage — CIS 1.7
# Root has unrestricted access to every AWS resource.
# Any API call from root is abnormal — day-to-day operations
# must use IAM roles. Root usage = immediate investigation required.
# -----------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "root_usage" {
  name        = "root-account-usage"
  description = "Detects any API call made by the root account"

  event_pattern = jsonencode({
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail" : {
      "userIdentity" : {
        "type" : ["Root"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "root_usage_sns" {
  rule      = aws_cloudwatch_event_rule.root_usage.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.root_usage.arn

  input_transformer {
    input_paths = {
      event   = "$.detail.eventName",
      time    = "$.detail.eventTime",
      user    = "$.detail.userIdentity.userName",
      account = "$.detail.userIdentity.accountId",
      source  = "$.detail.sourceIPAddress",
      console = "$.detail.sessionCredentialFromConsole"
    }
    input_template = "\"ALERT: Root Account usage has been detected!.\\n\\nSeverity: CRITICAL!. Detail:\\n\\nEvent: <event>\\nTime: <time>\\nUser: <user>\\nAccount: <account>\\nSource IP: <source>\\nConsole LogIn: <console>\\n\\nImmediate action required:\\n\\nPlease confirm if the <event> is legitimate. Thanks\""

  }
}

resource "aws_sns_topic" "root_usage" {
  name = "root-account-usage"
}

resource "aws_sns_topic_policy" "root_usage" {
  arn    = aws_sns_topic.root_usage.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

# Security team gets all alerts
resource "aws_sns_topic_subscription" "root_usage_security" {
  topic_arn = aws_sns_topic.root_usage.arn
  protocol  = "email"
  endpoint  = data.aws_ssm_parameter.security_email.value
}

# Root owner is notified only for root usage
resource "aws_sns_topic_subscription" "root_usage_owner" {
  topic_arn = aws_sns_topic.root_usage.arn
  protocol  = "email"
  endpoint  = data.aws_ssm_parameter.root_owner_email.value
}

# -----------------------------------------------------------------
# rule 3: CloudTrail configuration changes — CIS 3.5
# Disabling or modifying CloudTrail is a common attacker technique
# to eliminate audit trails before or during a breach.
# This is one of the highest-priority alerts.
# -----------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "cloudtrail_changes" {
  name        = "cloudtrail-config-changes"
  description = "Detects attempts to disable or modify CloudTrail audit logging"

  event_pattern = jsonencode({
    "source" : ["aws.cloudtrail"],
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail" : {
      "eventName" : [
        "StopLogging",
        "DeleteTrail",
        "UpdateTrail",
        "PutEventSelectors",
        "PutInsightSelectors"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "cloudtrail_changes_sns" {
  rule      = aws_cloudwatch_event_rule.cloudtrail_changes.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.cloudtrail_changes.arn

  input_transformer {
    input_paths = {
      event   = "$.detail.eventName",
      time    = "$.detail.eventTime",
      user    = "$.detail.userIdentity.userName",
      account = "$.detail.userIdentity.accountId",
      source  = "$.detail.sourceIPAddress",
      console = "$.detail.sessionCredentialFromConsole"
    }
    input_template = "\"ALERT: CloudTrail Configuration drift has been detected!.\\n\\nSeverity: CRITICAL!. Detail:\\n\\nEvent: <event>\\nTime: <time>\\nUser: <user>\\nAccount: <account>\\nSource IP: <source>\\nConsole LogIn: <console>\\n\\nImmediate action reuired:\\n\\nPlease confirm if the <event> is legitimate. Thanks\""

  }
}

resource "aws_sns_topic" "cloudtrail_changes" {
  name = "cloudtrail-config-changes"
}

resource "aws_sns_topic_policy" "cloudtrail_changes" {
  arn    = aws_sns_topic.cloudtrail_changes.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

resource "aws_sns_topic_subscription" "cloudtrail_changes_security" {
  topic_arn = aws_sns_topic.cloudtrail_changes.arn
  protocol  = "email"
  endpoint  = data.aws_ssm_parameter.security_email.value
}

# -----------------------------------------------------------------
# rule 4: Security Group changes — CIS 5.3
# Unauthorized ingress rules are the most common path to exposing internal resources (ECS, RDS) to the internet.
# -----------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "sg_changes" {
  name        = "security-group-changes"
  description = "Detects modifications to EC2 security group rules and group lifecycle"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail" : {
      "eventName" : [
        "AuthorizeSecurityGroupIngress",
        "AuthorizeSecurityGroupEgress",
        "RevokeSecurityGroupIngress",
        "RevokeSecurityGroupEgress",
        "CreateSecurityGroup",
        "DeleteSecurityGroup"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "sg_changes_sns" {
  rule      = aws_cloudwatch_event_rule.sg_changes.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.sg_changes.arn

  input_transformer {
    input_paths = {
      event   = "$.detail.eventName",
      time    = "$.detail.eventTime",
      user    = "$.detail.userIdentity.userName",
      account = "$.detail.userIdentity.accountId",
      source  = "$.detail.sourceIPAddress",
      console = "$.detail.sessionCredentialFromConsole"
    }
    input_template = "\"ALERT: Security Group Configuration changes has been detected!.\\n\\nSeverity: HIGH!. Detail:\\n\\nEvent: <event>\\nTime: <time>\\nUser: <user>\\nAccount: <account>\\nSource IP: <source>\\nConsole LogIn: <console>\\n\\nImmediate action reuired:\\n\\nPlease confirm if the <event> is legitimate. Thanks\""

  }
}

resource "aws_sns_topic" "sg_changes" {
  name = "security-group-changes"
}

resource "aws_sns_topic_policy" "sg_changes" {
  arn    = aws_sns_topic.sg_changes.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

resource "aws_sns_topic_subscription" "sg_changes_security" {
  topic_arn = aws_sns_topic.sg_changes.arn
  protocol  = "email"
  endpoint  = data.aws_ssm_parameter.security_email.value
}


# -----------------------------------------------------------------
# rule 5: Console login without MFA — CIS 1.10
# A successful console login without MFA is a credential hygiene failure. 
# Filter to Success only — failed logins without MFA are noise.
# -----------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "console_login_no_mfa" {
  name        = "console-login-no-mfa"
  description = "Detects successful AWS console logins that did not use MFA"

  event_pattern = jsonencode({
    "source" : ["aws.signin"],
    "detail-type" : ["AWS Console Sign In via CloudTrail"],
    "detail" : {
      "eventName" : ["ConsoleLogin"],
      "additionalEventData" : {
        "MFAUsed" : ["No"]
      },
      "responseElements" : {
        "ConsoleLogin" : ["Success"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "console_login_no_mfa_sns" {
  rule      = aws_cloudwatch_event_rule.console_login_no_mfa.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.console_login_no_mfa.arn

  input_transformer {
    input_paths = {
      event   = "$.detail.eventName",
      time    = "$.detail.eventTime",
      user    = "$.detail.userIdentity.userName",
      account = "$.detail.userIdentity.accountId",
      source  = "$.detail.sourceIPAddress",
      console = "$.detail.sessionCredentialFromConsole"
    }
    input_template = "\"ALERT: Console LogIn without MFA has been detected!.\\n\\nSeverity: HIGH!. Detail:\\n\\nEvent: <event>\\nTime: <time>\\nUser: <user>\\nAccount: <account>\\nSource IP: <source>\\nConsole LogIn: <console>\\n\\nImmediate action reuired:\\n\\nPlease confirm if the <event> is legitimate. Thanks\""

  }
}

resource "aws_sns_topic" "console_login_no_mfa" {
  name = "console-login-no-mfa"
}

resource "aws_sns_topic_policy" "console_login_no_mfa" {
  arn    = aws_sns_topic.console_login_no_mfa.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

resource "aws_sns_topic_subscription" "console_login_no_mfa_security" {
  topic_arn = aws_sns_topic.console_login_no_mfa.arn
  protocol  = "email"
  endpoint  = data.aws_ssm_parameter.security_email.value
}

# -----------------------------------------------------------------
# rule 6: KMS key deletion or disable — CIS 3.7
# ScheduleKeyDeletion has a 7–30 day waiting period. 
# This alert gives you time to cancel before data becomes permanently unrecoverable.
# DisableKey takes effect immediately — encrypted data is inaccessible until the key is re-enabled.
# -----------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "kms_key_changes" {
  name        = "kms-key-deletion-disable"
  description = "Detects KMS key deletion scheduling or disablement — loss of key = loss of encrypted data"

  event_pattern = jsonencode({
    "source" : ["aws.kms"],
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail" : {
      "eventName" : [
        "DisableKey",
        "ScheduleKeyDeletion"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "kms_key_changes_sns" {
  rule      = aws_cloudwatch_event_rule.kms_key_changes.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.kms_key_changes.arn

  input_transformer {
    input_paths = {
      event   = "$.detail.eventName",
      time    = "$.detail.eventTime",
      user    = "$.detail.userIdentity.userName",
      account = "$.detail.userIdentity.accountId",
      source  = "$.detail.sourceIPAddress",
      console = "$.detail.sessionCredentialFromConsole"
    }
    input_template = "\"ALERT: KMS key Configuration changes has been detected!.\\n\\nSeverity: HIGH!. Detail:\\n\\nEvent: <event>\\nTime: <time>\\nUser: <user>\\nAccount: <account>\\nSource IP: <source>\\nConsole LogIn: <console>\\n\\nImmediate action reuired:\\n\\nPlease confirm if the <event> is legitimate. Thanks\""

  }
}

resource "aws_sns_topic" "kms_key_changes" {
  name = "kms-key-deletion-disable"
}

resource "aws_sns_topic_policy" "kms_key_changes" {
  arn    = aws_sns_topic.kms_key_changes.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

resource "aws_sns_topic_subscription" "kms_key_changes_security" {
  topic_arn = aws_sns_topic.kms_key_changes.arn
  protocol  = "email"
  endpoint  = data.aws_ssm_parameter.security_email.value
}

# -----------------------------------------------------------------
# rule 7: Network ACL changes — CIS 4.11
# NACLs are a stateless layer of network control that sits in front of security groups. 
# Modifications can silently bypass SG-level controls or block legitimate traffic. 
# Less common to change than SGs — any change warrants review.
# -----------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "nacl_changes" {
  name        = "nacl-changes"
  description = "Detects modifications to Network ACL rules or associations"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail" : {
      "eventName" : [
        "CreateNetworkAcl",
        "CreateNetworkAclEntry",
        "DeleteNetworkAcl",
        "DeleteNetworkAclEntry",
        "ReplaceNetworkAclEntry",
        "ReplaceNetworkAclAssociation"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "nacl_changes_sns" {
  rule      = aws_cloudwatch_event_rule.nacl_changes.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.nacl_changes.arn

  input_transformer {
    input_paths = {
      event   = "$.detail.eventName",
      time    = "$.detail.eventTime",
      user    = "$.detail.userIdentity.userName",
      account = "$.detail.userIdentity.accountId",
      source  = "$.detail.sourceIPAddress",
      console = "$.detail.sessionCredentialFromConsole"
    }
    input_template = "\"ALERT: NACL Configuration changes has been detected!.\\n\\nSeverity: HIGH!. Detail:\\n\\nEvent: <event>\\nTime: <time>\\nUser: <user>\\nAccount: <account>\\nSource IP: <source>\\nConsole LogIn: <console>\\n\\nImmediate action reuired:\\n\\nPlease confirm if the <event> is legitimate. Thanks\""

  }
}

resource "aws_sns_topic" "nacl_changes" {
  name = "nacl-changes"
}

resource "aws_sns_topic_policy" "nacl_changes" {
  arn    = aws_sns_topic.nacl_changes.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

resource "aws_sns_topic_subscription" "nacl_changes_security" {
  topic_arn = aws_sns_topic.nacl_changes.arn
  protocol  = "email"
  endpoint  = data.aws_ssm_parameter.security_email.value
}
