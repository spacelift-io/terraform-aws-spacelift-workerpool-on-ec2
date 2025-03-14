locals {
  # Validation hack until https://github.com/opentofu/opentofu/issues/1336 is resolved
  #! IMPORTANT! This check works only for known during 'terraform plan' values of `var.custom_iam_role_name`.
  #! If IAM role name is not known during 'terraform plan', the check will be skipped and
  #! error message will pop up only after `terraform apply ' in the next 'terraform plan'.
  validate_condition = (!var.create_iam_role && length(var.custom_iam_role_name) == 0) || (var.create_iam_role && length(var.custom_iam_role_name) > 0)
  validate_message   = "The 'create_iam_role' has been set to '${var.create_iam_role}', when 'custom_iam_role_name' set to '${var.custom_iam_role_name}', which are mutually exclusive. To create a new IAM role inside module, set 'create_iam_role' to 'true' and 'custom_iam_role_name' to ''. To use a custom IAM role, set 'create_iam_role' to 'false' and 'custom_iam_role_name' to the name of the custom IAM role."
  validate_check = regex(
    "^${local.validate_message}$",
    (!local.validate_condition
      ? local.validate_message
  : ""))
}

data "aws_partition" "current" {}

resource "aws_iam_role" "this" {
  count = var.create_iam_role ? 1 : 0
  name  = local.base_name
  path  = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.${data.aws_partition.current.dns_suffix}" }
    }]
  })
  tags                 = var.additional_tags
  permissions_boundary = var.permissions_boundary
}

locals {
  iam_managed_policies = var.create_iam_role ? [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AutoScalingReadOnlyAccess",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ] : []
}
resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset(local.iam_managed_policies)

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "s3" {
  count = var.create_iam_role && var.selfhosted_configuration.s3_uri != "" ? 1 : 0

  name = "s3-access"
  role = aws_iam_role.this[0].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = [format("arn:${data.aws_partition.current.partition}:s3:::%s/*", split("/", var.selfhosted_configuration.s3_uri)[2])]
    }]
  })
}

resource "aws_iam_instance_profile" "this" {
  depends_on = [aws_iam_role_policy_attachment.this]

  name = local.base_name
  role = var.create_iam_role ? aws_iam_role.this[0].name : var.custom_iam_role_name
  tags = var.additional_tags
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
    resources = [aws_ssm_parameter.spacelift_api_key_secret[count.index].arn]
  }
}

resource "aws_iam_role" "autoscaler" {
  count = var.enable_autoscaling ? 1 : 0
  name  = local.function_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.${data.aws_partition.current.dns_suffix}"
        },
        "Action" : "sts:AssumeRole"
      },
    ]
  })

  depends_on           = [module.asg]
  tags                 = var.additional_tags
  permissions_boundary = var.permissions_boundary
}

resource "aws_iam_role_policy" "autoscaler" {
  count  = var.enable_autoscaling ? 1 : 0
  name   = "ec2-autoscaler-${var.worker_pool_id}"
  role   = aws_iam_role.autoscaler[0].name
  policy = data.aws_iam_policy_document.autoscaler[count.index].json
}
