module "autoscaler" {
  source = "github.com/spacelift-io/ec2-workerpool-autoscaler//iac"

  for_each = var.enable_autoscaling ? toset(["ENABLED"]) : toset([])

  autoscaling_group_arn      = var.autoscaling_group_arn
  autoscaler_version         = var.autoscaler_version
  spacelift_api_key_id       = var.spacelift_api_key_id
  spacelift_api_key_secret   = var.spacelift_api_key_secret
  spacelift_api_key_endpoint = var.spacelift_api_key_endpoint
  worker_pool_id             = var.worker_pool_id
  autoscaler_architecture    = var.autoscaler_architecture
  autoscaling_timeout        = var.autoscaling_timeout
  autoscaling_max_create     = var.autoscaling_max_create
  autoscaling_max_terminate  = var.autoscaling_max_terminate
  schedule_expression        = var.schedule_expression
  base_name                  = var.base_name
  region                     = var.region
  autoscaler_s3_package      = var.autoscaler_s3_package
  subnet_ids                 = var.subnet_ids
  security_group_ids         = var.security_group_ids

  depends_on = [module.asg]
}

<<<<<<< HEAD
resource "aws_ssm_parameter" "spacelift_api_key_secret" {
  count = var.enable_autoscaling ? 1 : 0
  name  = "/${local.function_name}/spacelift-api-secret-${var.worker_pool_id}"
  type  = "SecureString"
  value = var.spacelift_api_key_secret
  tags  = var.additional_tags
=======
moved {
  from = aws_ssm_parameter.spacelift_api_key_secret[0]
  to   = module.autoscaler["ENABLED"].aws_ssm_parameter.spacelift_api_key_secret
>>>>>>> ccf916b (feat: uses autoscaler module instead of repeating code)
}

moved {
  from = null_resource.download[0]
  to   = module.autoscaler["ENABLED"].null_resource.download
}

moved {
  from = aws_lambda_function.autoscaler[0]
  to   = module.autoscaler["ENABLED"].aws_lambda_function.autoscaler
}

<<<<<<< HEAD
resource "aws_lambda_function" "autoscaler" {
  count = var.enable_autoscaling ? 1 : 0

  filename         = !local.use_s3_package ? data.archive_file.binary[count.index].output_path : null
  source_code_hash = !local.use_s3_package ? data.archive_file.binary[count.index].output_base64sha256 : null

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
=======
moved {
  from = aws_cloudwatch_event_rule.scheduling[0]
  to   = module.autoscaler["ENABLED"].aws_cloudwatch_event_rule.scheduling
}

moved {
  from = aws_cloudwatch_event_target.scheduling[0]
  to   = module.autoscaler["ENABLED"].aws_cloudwatch_event_target.scheduling
>>>>>>> ccf916b (feat: uses autoscaler module instead of repeating code)
}

moved {
  from = aws_lambda_permission.allow_cloudwatch_to_call_lambda[0]
  to   = module.autoscaler["ENABLED"].aws_lambda_permission.allow_cloudwatch_to_call_lambda
}

moved {
  from = aws_cloudwatch_log_group.log_group[0]
  to   = module.autoscaler["ENABLED"].aws_cloudwatch_log_group.log_group
}

<<<<<<< HEAD
resource "aws_cloudwatch_log_group" "log_group" {
  count             = var.enable_autoscaling ? 1 : 0
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 7
  tags              = var.additional_tags
=======
moved {
  from = aws_iam_role.autoscaler[0]
  to   = module.autoscaler["ENABLED"].aws_iam_role.autoscaler
>>>>>>> ccf916b (feat: uses autoscaler module instead of repeating code)
}
