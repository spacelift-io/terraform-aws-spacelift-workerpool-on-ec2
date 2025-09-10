locals {
  download_folder    = var.worker_pool_id # Unique folder name to avoid race conditions when downloading the archive in parallel
  architecture       = coalesce(var.autoscaling_configuration.architecture, "amd64")
  autoscaler_zip     = "${local.download_folder}/ec2-workerpool-autoscaler_linux_${local.architecture}.zip"
  function_name      = "${var.base_name}-ec2-autoscaler"
  use_s3_package     = var.autoscaling_configuration.s3_package != null
  autoscaler_version = coalesce(var.autoscaling_configuration.version, "latest")
}

resource "null_resource" "download" {
  count = !local.use_s3_package ? 1 : 0
  triggers = {
    # Always re-download the archive file if the version is set to "latest" or if the file does not exist
    keeper = (
      local.autoscaler_version == "latest" || !fileexists(local.autoscaler_zip)
      ? timestamp()
      : local.autoscaler_version
    )
  }

  provisioner "local-exec" {
    command = "${path.module}/download.sh ${local.autoscaler_version} ${local.architecture} ${local.download_folder}"
  }
}

data "local_file" "autoscaler_zip" {
  count      = !local.use_s3_package ? 1 : 0
  depends_on = [null_resource.download]
  filename   = local.autoscaler_zip
}

resource "aws_lambda_function" "autoscaler" {
  # If we don't use a custom S3 package, we use the downloaded binary
  filename         = !local.use_s3_package ? data.local_file.autoscaler_zip[0].filename : null
  source_code_hash = !local.use_s3_package ? data.local_file.autoscaler_zip[0].content_base64sha256 : null

  # If we use a custom S3 package, we use the provided bucket / key / object version
  s3_bucket         = local.use_s3_package ? var.autoscaling_configuration.s3_package.bucket : null
  s3_key            = local.use_s3_package ? var.autoscaling_configuration.s3_package.key : null
  s3_object_version = local.use_s3_package ? var.autoscaling_configuration.s3_package.object_version : null

  function_name = local.function_name
  role          = aws_iam_role.autoscaler.arn
  handler       = "bootstrap"
  runtime       = "provided.al2"
  architectures = [var.autoscaling_configuration.architecture == "amd64" ? "x86_64" : coalesce(var.autoscaling_configuration.architecture, "x86_64")]
  timeout       = var.autoscaling_configuration.timeout != null ? var.autoscaling_configuration.timeout : 30

  dynamic "vpc_config" {
    for_each = var.spacelift_vpc_subnet_ids != null && var.spacelift_vpc_security_group_ids != null ? ["USE_VPC_CONFIG"] : []
    content {
      security_group_ids          = var.spacelift_vpc_security_group_ids
      subnet_ids                  = var.spacelift_vpc_subnet_ids
      ipv6_allowed_for_dual_stack = var.ipv6_allowed_for_dual_stack
    }
  }

  environment {
    variables = {
      AUTOSCALING_GROUP_ARN         = var.auto_scaling_group_arn
      AUTOSCALING_REGION            = var.aws_region
      SPACELIFT_API_KEY_ID          = var.spacelift_api_credentials.api_key_id
      SPACELIFT_API_KEY_SECRET_NAME = var.api_key_ssm_parameter_name
      SPACELIFT_API_KEY_ENDPOINT    = var.spacelift_api_credentials.api_key_endpoint
      SPACELIFT_WORKER_POOL_ID      = var.worker_pool_id
      AUTOSCALING_MAX_CREATE        = var.autoscaling_configuration.max_create != null ? var.autoscaling_configuration.max_create : 1
      AUTOSCALING_MAX_KILL          = var.autoscaling_configuration.max_terminate != null ? var.autoscaling_configuration.max_terminate : 1
      AUTOSCALING_SCALE_DOWN_DELAY  = var.autoscaling_configuration.scale_down_delay != null ? var.autoscaling_configuration.scale_down_delay : 0
    }
  }

  tracing_config {
    mode = var.tracing_mode
  }
}

resource "aws_cloudwatch_event_rule" "scheduling" {
  name                = local.function_name
  description         = "Spacelift autoscaler scheduling for worker pool ${var.worker_pool_id}"
  schedule_expression = coalesce(var.autoscaling_configuration.schedule_expression, "rate(1 minute)")
}

resource "aws_cloudwatch_event_target" "scheduling" {
  rule = aws_cloudwatch_event_rule.scheduling.name
  arn  = aws_lambda_function.autoscaler.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.autoscaler.function_name
  principal     = "events.${var.aws_partition_dns_suffix}"
  source_arn    = aws_cloudwatch_event_rule.scheduling.arn
}

resource "aws_cloudwatch_log_group" "log_group" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.cloudwatch_log_group_retention
}
