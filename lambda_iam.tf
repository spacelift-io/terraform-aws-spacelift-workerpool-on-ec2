locals {
  lambda_role_enabled = local.autoscaler_or_lifecycle_manager_enabled

  # Secrets both Lambdas may need to read: external secret_env_var_arns, the
  # unified secret (CA bundle today; destined to hold more later), and the
  # per-key sensitive env var secrets each submodule creates.
  lambda_secret_arns = compact(concat(
    values(var.secret_env_var_arns),
    [local.ca_bundle_secret_arn],
    local.autoscaling_enabled ? module.autoscaler[0].sensitive_env_var_secret_arns : [],
    local.lifecycle_manager_enabled ? module.lifecycle_manager[0].sensitive_env_var_secret_arns : [],
  ))
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda" {
  count = local.lambda_role_enabled ? 1 : 0

  name = "${local.base_name}-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.${data.aws_partition.current.dns_suffix}" }
    }]
  })
  permissions_boundary = var.iam_permissions_boundary
  tags                 = var.additional_tags
}

data "aws_iam_policy_document" "lambda" {
  count = local.lambda_role_enabled ? 1 : 0

  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.this.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.base_name}*:*"]
  }

  statement {
    sid       = "Xray"
    effect    = "Allow"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }

  # DescribeAutoScalingGroups does not support resource-level permissions.
  statement {
    sid       = "AutoscalingDescribe"
    effect    = "Allow"
    actions   = ["autoscaling:DescribeAutoScalingGroups"]
    resources = ["*"]
  }

  statement {
    sid    = "AutoscalingMutate"
    effect = "Allow"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:CompleteLifecycleAction",
      "autoscaling:RecordLifecycleActionHeartbeat",
    ]
    resources = [module.asg.autoscaling_group_arn]
  }

  statement {
    sid    = "EC2"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:AttachNetworkInterface",
    ]
    resources = ["*"]
  }

  # The lifecycle manager Lambda is triggered by this queue (receive/delete) and
  # re-queues messages with a delay while a worker is still draining (send).
  dynamic "statement" {
    for_each = local.lifecycle_manager_enabled ? ["SQS"] : []
    content {
      sid       = "SQS"
      effect    = "Allow"
      actions   = ["sqs:*"]
      resources = [module.lifecycle_manager[0].sqs_arn]
    }
  }

  statement {
    sid       = "SSM"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = [local.ssm_arn]
  }

  dynamic "statement" {
    for_each = length(local.lambda_secret_arns) > 0 ? ["SECRETS"] : []
    content {
      sid       = "Secrets"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = local.lambda_secret_arns
    }
  }
}

resource "aws_iam_role_policy" "lambda" {
  count = local.lambda_role_enabled ? 1 : 0

  name   = "${local.base_name}-lambda"
  role   = aws_iam_role.lambda[0].name
  policy = data.aws_iam_policy_document.lambda[0].json
}
