moved {
  from = data.aws_ami.this
  to   = data.aws_ami.this[0]
}

moved {
  from = aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AutoScalingReadOnlyAccess"]
  to   = aws_iam_role_policy_attachment.this["autoscaling_ro"]
}

moved {
  from = aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  to   = aws_iam_role_policy_attachment.this["ssm_managed_core"]
}

moved {
  from = aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
  to   = aws_iam_role_policy_attachment.this["cloudwatch_agent"]
}

moved {
  from = aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"]
  to   = aws_iam_role_policy_attachment.this["asg_notification"]
}
