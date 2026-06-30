output "sqs_arn" {
  value       = aws_sqs_queue.this.arn
  description = "ARN of the SQS queue."
}

output "sensitive_env_var_secret_arns" {
  description = "ARNs of the per-key Secrets Manager secrets created for sensitive env vars."
  value       = [for secret in aws_secretsmanager_secret.sensitive_env_var : secret.arn]
}