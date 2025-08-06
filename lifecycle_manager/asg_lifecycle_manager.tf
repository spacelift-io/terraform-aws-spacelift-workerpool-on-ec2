locals {
  lifecycle_code = "${path.module}/ec2-workerpool-lifecycle-manager.zip"
  name           = length("${var.base_name}-lifecycle-manager") <= 64 ? "${var.base_name}-lifecycle-manager" : "${var.base_name}-lcm"
}

resource "aws_sqs_queue" "this" {
  name = local.name
  tags = merge(
    var.additional_tags,
    {
      Name = local.name
    },
  )
}

resource "aws_lambda_function" "this" {
  filename         = local.lifecycle_code
  source_code_hash = filebase64sha256(local.lifecycle_code)

  function_name = local.name
  role          = aws_iam_role.this.arn
  handler       = "main.main"
  runtime       = "python3.13"

  # Realistically, this function is just doing a few API calls and then immediately putting the
  # message back onto the queue if it cant doing anything. Like if its waiting for a worker to drain.
  # So if this takes more than 15 seconds, something is probably wrong.
  timeout = 15

  environment {
    variables = {
      AUTOSCALING_GROUP_ARN         = var.auto_scaling_group_arn
      AUTOSCALING_REGION            = var.aws_region
      SPACELIFT_API_KEY_ID          = var.spacelift_api_credentials.api_key_id
      SPACELIFT_API_KEY_SECRET_NAME = var.api_key_ssm_parameter_name
      SPACELIFT_API_KEY_ENDPOINT    = var.spacelift_api_credentials.api_key_endpoint
      SPACELIFT_WORKER_POOL_ID      = var.worker_pool_id
      QUEUE_URL                     = aws_sqs_queue.this.url
    }
  }
}

resource "aws_lambda_event_source_mapping" "this" {
  function_name    = aws_lambda_function.this.function_name
  event_source_arn = aws_sqs_queue.this.arn
}

resource "aws_cloudwatch_log_group" "log_group" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = var.cloudwatch_log_group_retention
}

