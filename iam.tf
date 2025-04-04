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
  permissions_boundary = var.iam_permissions_boundary

  tags = var.additional_tags
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

resource "aws_iam_role_policy_attachment" "secure_env_vars" {
  count      = local.has_secure_env_vars && var.create_iam_role ? 1 : 0
  role       = aws_iam_role.this[0].name
  policy_arn = aws_iam_policy.secure_env_vars[0].arn
}

resource "aws_iam_instance_profile" "this" {
  depends_on = [aws_iam_role_policy_attachment.this]

  name = local.base_name
  role = var.create_iam_role ? aws_iam_role.this[0].name : var.custom_iam_role_name
  tags = var.additional_tags
}

data "aws_kms_key" "secure_env_vars" {
  count = local.has_secure_env_vars && var.create_iam_role ? 1 : 0

  key_id = var.secure_env_vars_kms_key_id
}

data "aws_iam_policy_document" "secure_env_vars" {
  count = local.has_secure_env_vars && var.create_iam_role ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [aws_secretsmanager_secret.this[0].arn]
  }

  dynamic "statement" {
    for_each = var.secure_env_vars_kms_key_id != null ? ["USE_KMS_KEY"] : []
    content {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKey",
      ]
      resources = [data.aws_kms_key.secure_env_vars[0].arn]
    }
  }
}

resource "aws_iam_policy" "secure_env_vars" {
  count = local.has_secure_env_vars && var.create_iam_role ? 1 : 0

  name        = "${local.base_name}-secure-strings"
  description = "Allows access to the secure strings stored in Secrets Manager"
  policy      = data.aws_iam_policy_document.secure_env_vars[count.index].json
}
