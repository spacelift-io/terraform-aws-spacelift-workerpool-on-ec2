resource "aws_iam_role" "iam" {
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

resource "aws_iam_role_policy_attachment" "attachments" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AutoScalingReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess",
  ])

  role       = aws_iam_role.iam.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "instances" {
  depends_on = [aws_iam_role_policy_attachment.attachments]

  name = local.namespace
  role = aws_iam_role.iam.name
}
