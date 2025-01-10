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

resource "aws_iam_role" "this" {
  count = var.create_iam_role ? 1 : 0
  name  = local.base_name
  path  = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = var.additional_tags
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

  name = local.base_name
  role = var.create_iam_role ? aws_iam_role.this[0].name : var.custom_iam_role_name
  tags = var.additional_tags
}

