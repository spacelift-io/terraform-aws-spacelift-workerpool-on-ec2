data "aws_iam_policy_document" "this" {
  # Allow the Lambda to write CloudWatch Logs.
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${aws_cloudwatch_log_group.log_group.arn}:*"]
  }

  # Allow the Lambda to Complete Lifecycle Actions
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:CompleteLifecycleAction"
    ]

    resources = [var.auto_scaling_group_arn]
  }

  # Allow the lambda to do sqs operations on its queue
  statement {
    effect = "Allow"
    actions = [
      "sqs:*",
    ]

    resources = [aws_sqs_queue.this.arn]
  }

  # Allow the Lambda to read the secret from SSM Parameter Store.
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = [var.api_key_ssm_parameter_arn]
  }
}

resource "aws_iam_role" "this" {
  name = local.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.${var.aws_partition_dns_suffix}"
        },
        "Action" : "sts:AssumeRole"
      },
    ]
  })
  tags                 = var.additional_tags
  permissions_boundary = var.iam_permissions_boundary
}

resource "aws_iam_role_policy" "this" {
  name   = local.name
  role   = aws_iam_role.this.name
  policy = data.aws_iam_policy_document.this.json
}
