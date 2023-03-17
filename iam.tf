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
