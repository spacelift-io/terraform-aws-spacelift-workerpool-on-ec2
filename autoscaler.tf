locals {
  autoscaler_zip = "${path.module}/ec2-workerpool-autoscaler_${var.autoscaler_version}.zip"
  function_name  = "${local.base_name}-ec2-autoscaler"
  use_s3_package = var.autoscaler_s3_package != null
}

resource "aws_ssm_parameter" "spacelift_api_key_secret" {
  count = var.enable_autoscaling ? 1 : 0
  name  = "/${local.function_name}/spacelift-api-secret-${var.worker_pool_id}"
  type  = "SecureString"
  value = var.spacelift_api_key_secret
  tags  = var.additional_tags
}

resource "null_resource" "download" {
  count = var.enable_autoscaling && !local.use_s3_package ? 1 : 0
  triggers = {
    # Always re-download the archive file if the version is set to "latest" or if the file does not exist
    keeper = (
      var.autoscaler_version == "latest" || !fileexists(local.autoscaler_zip)
      ? timestamp()
      : var.autoscaler_version
    )
  }
}

resource "local_file" "autoscaler_zip" {
  count    = var.enable_autoscaling && !local.use_s3_package ? 1 : 0
  filename = local.autoscaler_zip
  content  = "placeholder"

  lifecycle {
    replace_triggered_by = [
      null_resource.download
    ]
  }

  provisioner "local-exec" {
    command = "${path.module}/download.sh ${var.autoscaler_version} ${var.autoscaler_architecture}"
  }
}

resource "aws_lambda_function" "autoscaler" {
  count = var.enable_autoscaling ? 1 : 0

  filename         = !local.use_s3_package ? local_file.autoscaler_zip[count.index].filename : null
  source_code_hash = !local.use_s3_package ? local_file.autoscaler_zip[count.index].content_base64sha256 : null

  s3_bucket         = local.use_s3_package ? var.autoscaler_s3_package.bucket : null
  s3_key            = local.use_s3_package ? var.autoscaler_s3_package.key : null
  s3_object_version = local.use_s3_package ? var.autoscaler_s3_package.object_version : null

  function_name = local.function_name
  role          = aws_iam_role.autoscaler[count.index].arn
  handler       = "bootstrap"
  runtime       = "provided.al2"
  architectures = [var.autoscaler_architecture == "amd64" ? "x86_64" : var.autoscaler_architecture]
  timeout       = var.autoscaling_timeout

  environment {
    variables = {
      AUTOSCALING_GROUP_ARN         = module.asg.autoscaling_group_arn
      AUTOSCALING_REGION            = data.aws_region.this.name
      SPACELIFT_API_KEY_ID          = var.spacelift_api_key_id
      SPACELIFT_API_KEY_SECRET_NAME = aws_ssm_parameter.spacelift_api_key_secret[count.index].name
      SPACELIFT_API_KEY_ENDPOINT    = var.spacelift_api_key_endpoint
      SPACELIFT_WORKER_POOL_ID      = var.worker_pool_id
      AUTOSCALING_MAX_CREATE        = var.autoscaling_max_create
      AUTOSCALING_MAX_KILL          = var.autoscaling_max_terminate
    }
  }

  tracing_config {
    mode = "Active"
  }
  tags = var.additional_tags
}

resource "aws_cloudwatch_event_rule" "scheduling" {
  count               = var.enable_autoscaling ? 1 : 0
  name                = local.function_name
  description         = "Spacelift autoscaler scheduling for worker pool ${var.worker_pool_id}"
  schedule_expression = var.schedule_expression
  tags                = var.additional_tags
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
  principal     = "events.${data.aws_partition.current.dns_suffix}"
  source_arn    = aws_cloudwatch_event_rule.scheduling[count.index].arn
}

resource "aws_cloudwatch_log_group" "log_group" {
  count             = var.enable_autoscaling ? 1 : 0
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 7
  tags              = var.additional_tags
}
