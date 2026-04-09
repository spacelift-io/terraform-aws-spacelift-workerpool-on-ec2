output "log_group_name" {
  description = "Name of the CloudWatch log group for the autoscaler Lambda"
  value       = aws_cloudwatch_log_group.log_group.name
}
