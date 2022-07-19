resource "aws_iam_role" "this" {
  name = local.namespace
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AutoScalingReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "this" {
  depends_on = [aws_iam_role_policy_attachment.this]

  name = local.namespace
  role = aws_iam_role.this.name
}
