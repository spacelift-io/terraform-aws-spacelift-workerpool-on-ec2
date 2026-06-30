output "log_group_name" {
  description = "Name of the CloudWatch log group for the autoscaler Lambda"
  value       = aws_cloudwatch_log_group.log_group.name
}

output "sensitive_env_var_secret_arns" {
  description = "ARNs of the per-key Secrets Manager secrets created for sensitive env vars."
  value       = [for secret in aws_secretsmanager_secret.sensitive_env_var : secret.arn]
}
