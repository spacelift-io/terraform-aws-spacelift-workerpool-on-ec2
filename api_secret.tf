resource "aws_ssm_parameter" "spacelift_api_key_secret" {
  name = "/ec2-autoscaler/spacelift-api-secret-${var.worker_pool_id}"
  type = "SecureString"
  value = var.spacelift_api_key_secret
}