resource "aws_iam_role" "this" {
  count = var.create_iam_role ? 1 : 0
  name  = local.namespace
  path  = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

locals {
  iam_managed_policies = var.create_iam_role ? [
    "arn:aws:iam::aws:policy/AutoScalingReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ] : []
}
resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset(local.iam_managed_policies)

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "this" {
  depends_on = [aws_iam_role_policy_attachment.this]

  name = local.namespace
  role = var.create_iam_role ? aws_iam_role.this[0].name : var.iam_role_arn
}

data "aws_iam_policy_document" "autoscaler" {
  count = var.enable_autoscaling ? 1 : 0
  # Allow the Lambda to write CloudWatch Logs.
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${aws_cloudwatch_log_group.log_group[count.index].arn}:*"]
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

    resources = [module.asg.autoscaling_group_arn]
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
    resources = [aws_ssm_parameter.spacelift_api_key_secret[count.index].arn]
  }
}

resource "aws_iam_role" "autoscaler" {
  count = var.enable_autoscaling ? 1 : 0
  name  = "ec2-autoscaler-${var.worker_pool_id}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      },
    ]
  })

  inline_policy {
    name   = "ec2-autoscaler-${var.worker_pool_id}"
    policy = data.aws_iam_policy_document.autoscaler[count.index].json
  }

  depends_on = [module.asg]
}
