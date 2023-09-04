locals {
  code_version = var.autoscaler_version
  package_path = var.local_path
  function_name = "ec2-autoscaler-${var.worker_pool_id}"
}

data "external" "package" {
  program = [
    "${path.module}/download.sh",
    local.code_version,
    local.package_path,
  ]
}

resource "aws_lambda_function" "autoscaler" {
  filename         = local.package_path
  source_code_hash = data.external.package.result.source_code_hash
  function_name    = local.function_name
  role             = aws_iam_role.lambda.arn
  handler          = "ec2-workerpool-autoscaler_v${var.autoscaler_version}"

  runtime                        = "go1.x"

  environment {
    variables = {
      AUTOSCALING_GROUP_ARN         = module.asg.autoscaling_group_arn
      AUTOSCALING_REGION            = data.aws_region.this.name
      SPACELIFT_API_KEY_ID          = var.spacelift_api_key_id
      SPACELIFT_API_KEY_SECRET_NAME = aws_ssm_parameter.spacelift_api_key_secret.name
      SPACELIFT_API_KEY_ENDPOINT    = var.spacelift_url
      SPACELIFT_WORKER_POOL_ID      = var.worker_pool_id
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [ module.asg ]
}

resource "aws_cloudwatch_event_rule" "scheduling" {
  name                = "spacelift-${var.worker_pool_id}-scheduling"
  description         = "Spacelift autoscaler scheduling for worker pool ${var.worker_pool_id}"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "scheduling" {
  rule = aws_cloudwatch_event_rule.scheduling.name
  arn  = aws_lambda_function.autoscaler.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_foo" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.autoscaler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduling.arn
}
