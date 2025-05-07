output "sqs_arn" {
  value       = aws_sqs_queue.this.arn
  description = "ARN of the SQS queue."
}