locals {
  function_name = "${local.base_name}-ec2-autoscaler"
}

resource "aws_ssm_parameter" "spacelift_api_key_secret" {
  count = var.enable_autoscaling ? 1 : 0
  name  = "/${local.function_name}/spacelift-api-secret-${var.worker_pool_id}"
  type  = "SecureString"
  value = var.spacelift_api_key_secret
}

resource "null_resource" "download" {
  count = var.enable_autoscaling ? 1 : 0
  provisioner "local-exec" {
    command = "${path.module}/download.sh ${var.autoscaler_version}"
  }
}

data "archive_file" "binary" {
  count       = var.enable_autoscaling ? 1 : 0
  type        = "zip"
  source_file = "lambda/bootstrap"
  output_path = "ec2-workerpool-autoscaler_${var.autoscaler_version}.zip"
  depends_on  = [null_resource.download]
}

resource "aws_lambda_function" "autoscaler" {
  count            = var.enable_autoscaling ? 1 : 0
  filename         = data.archive_file.binary[count.index].output_path
  source_code_hash = data.archive_file.binary[count.index].output_base64sha256
  function_name    = local.function_name
  role             = aws_iam_role.autoscaler[count.index].arn
  handler          = "bootstrap"
  runtime          = "provided.al2"

  environment {
    variables = {
      AUTOSCALING_GROUP_ARN         = module.asg.autoscaling_group_arn
      AUTOSCALING_REGION            = data.aws_region.this.name
      SPACELIFT_API_KEY_ID          = var.spacelift_api_key_id
      SPACELIFT_API_KEY_SECRET_NAME = aws_ssm_parameter.spacelift_api_key_secret[count.index].name
      SPACELIFT_API_KEY_ENDPOINT    = var.spacelift_api_key_endpoint
      SPACELIFT_WORKER_POOL_ID      = var.worker_pool_id
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [module.asg, null_resource.download]
}

resource "aws_cloudwatch_event_rule" "scheduling" {
  count               = var.enable_autoscaling ? 1 : 0
  name                = local.function_name
  description         = "Spacelift autoscaler scheduling for worker pool ${var.worker_pool_id}"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "scheduling" {
  count = var.enable_autoscaling ? 1 : 0
  rule  = aws_cloudwatch_event_rule.scheduling[count.index].name
  arn   = aws_lambda_function.autoscaler[count.index].arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  count         = var.enable_autoscaling ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.autoscaler[count.index].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduling[count.index].arn
}

resource "aws_cloudwatch_log_group" "log_group" {
  count             = var.enable_autoscaling ? 1 : 0
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 7
}
