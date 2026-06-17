locals {
  # Non-sensitive value entries — passed directly as Lambda env vars.
  env_vars_direct = {
    for name, cfg in var.env_vars :
    name => cfg.value
    if cfg.value != null && cfg.sensitive != true
  }

  # Sensitive value entries — stored as individual Secrets Manager secrets so
  # the value is never embedded in the Lambda configuration.
  env_vars_sensitive_values = {
    for name, cfg in var.env_vars :
    name => cfg.value
    if cfg.value != null && cfg.sensitive == true
  }

  # NAME_SECRET_ARN env vars: explicit secret_env_var_arns entries + sensitive value secrets.
  env_vars_secret_refs = merge(
    { for name, arn in var.secret_env_var_arns : "${name}_SECRET_ARN" => arn },
    { for name, secret in aws_secretsmanager_secret.sensitive_env_var : "${name}_SECRET_ARN" => secret.arn }
  )

  # All secret ARNs the Lambda IAM role needs to read.
  env_vars_secret_arns = concat(
    values(var.secret_env_var_arns),
    [for _, secret in aws_secretsmanager_secret.sensitive_env_var : secret.arn],
  )
}

# Individual Secrets Manager secrets for each sensitive value entry.
resource "aws_secretsmanager_secret" "sensitive_env_var" {
  for_each = nonsensitive(toset(keys(local.env_vars_sensitive_values)))

  name                    = "${local.name}-env-${each.key}"
  recovery_window_in_days = 0
  tags                    = var.additional_tags
}

resource "aws_secretsmanager_secret_version" "sensitive_env_var" {
  for_each = nonsensitive(toset(keys(local.env_vars_sensitive_values)))

  secret_id     = aws_secretsmanager_secret.sensitive_env_var[each.key].id
  secret_string = local.env_vars_sensitive_values[each.key]
}

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

  dynamic "vpc_config" {
    for_each = var.spacelift_vpc_subnet_ids != null && var.spacelift_vpc_security_group_ids != null ? ["USE_VPC_CONFIG"] : []
    content {
      security_group_ids          = var.spacelift_vpc_security_group_ids
      subnet_ids                  = var.spacelift_vpc_subnet_ids
      ipv6_allowed_for_dual_stack = var.ipv6_allowed_for_dual_stack
    }
  }

  environment {
    variables = merge({
      AUTOSCALING_GROUP_ARN         = var.auto_scaling_group_arn
      AUTOSCALING_REGION            = var.aws_region
      SPACELIFT_API_KEY_ID          = var.spacelift_api_credentials.api_key_id
      SPACELIFT_API_KEY_SECRET_NAME = var.api_key_ssm_parameter_name
      SPACELIFT_API_KEY_ENDPOINT    = var.spacelift_api_credentials.api_key_endpoint
      SPACELIFT_WORKER_POOL_ID      = var.worker_pool_id
      QUEUE_URL                     = aws_sqs_queue.this.url
      LIFECYCLE_HOOK_TIMEOUT        = var.lifecycle_hook_timeout
    }, var.ca_bundle_secret_arn != null ? { SPACELIFT_CA_BUNDLE_SECRET_ARN = var.ca_bundle_secret_arn } : {}, local.env_vars_direct, local.env_vars_secret_refs)
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

