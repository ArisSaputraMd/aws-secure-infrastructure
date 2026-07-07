
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.waf_autoblock.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.waf_alerts.arn
}

#zip the lambda_function.py on every plan/apply automatically
data "archive_file" "waf_autoblock_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/waf_autoblock/lambda_function.py"
  output_path = "${path.module}/lambda/waf_autoblock/waf_autoblock.zip"
}

resource "aws_lambda_function" "waf_autoblock" {
  function_name    = "${var.project_name}-${var.environment}-waf-autoblock"
  role             = aws_iam_role.waf_autoblock_lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.waf_autoblock_zip.output_path
  source_code_hash = data.archive_file.waf_autoblock_zip.output_base64sha256

  environment {
    variables = {
      WEB_ACL_ARN = aws_wafv2_web_acl.web_acl.arn
      IP_SET_ID   = aws_wafv2_ip_set.auto_blocked_ips.id
      IP_SET_NAME = aws_wafv2_ip_set.auto_blocked_ips.name
    }
  }
}
