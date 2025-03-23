
data "aws_iam_policy_document" "autoscaler" {
  # Allow the Lambda to write CloudWatch Logs.
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${aws_cloudwatch_log_group.log_group.arn}:*"]
  }

  # Allow the Lambda to put X-Ray traces.
  statement {
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]

    resources = ["*"]
  }

  # Allow the Lambda to DescribeAutoScalingGroups, DetachInstances and SetDesiredCapacity
  # on the AutoScalingGroup.
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DetachInstances",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:DescribeAutoScalingGroups",
    ]

    resources = ["*"]
  }

  # Allow the Lambda to DescribeInstances and TerminateInstances on the EC2 instances.
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:TerminateInstances",
    ]

    resources = ["*"]
  }

  # Allow the Lambda to read the secret from SSM Parameter Store.
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.spacelift_api_key_secret.arn]
  }
}

resource "aws_iam_role" "autoscaler" {
  name = local.function_name
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

resource "aws_iam_role_policy" "autoscaler" {
  name   = "ec2-autoscaler-${var.worker_pool_id}"
  role   = aws_iam_role.autoscaler.name
  policy = data.aws_iam_policy_document.autoscaler.json
}
