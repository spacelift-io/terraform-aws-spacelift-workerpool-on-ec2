output "instances_role_arn" {
  description = "ARN of the IAM role of the EC2 instances"
  value       = aws_iam_role.this.arn
}

output "instances_role_name" {
  description = "Name of the IAM role of the EC2 instances"
  value       = aws_iam_role.this.name
}

output "autoscaling_group_arn" {
  value       = module.asg.autoscaling_group_arn
  description = "ARN of the auto scaling group"
}

output "launch_configuration_id" {
  value       = module.asg.launch_configuration_id
  description = "ID of the launch configuration"
}
