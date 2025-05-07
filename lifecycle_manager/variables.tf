variable "api_key_ssm_parameter_arn" {
  type = string
}

variable "api_key_ssm_parameter_name" {
  type = string
}

variable "base_name" {
  type = string
}

variable "worker_pool_id" {
  type = string
}

variable "aws_partition_dns_suffix" {
  type = string
}

variable "auto_scaling_group_arn" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
}

variable "iam_permissions_boundary" {
  type        = string
  description = "ARN of the policy that is used to set the permissions boundary for any IAM roles."
}

variable "cloudwatch_log_group_retention" {
  description = "Retention period for the lifecycle manager cloudwatch log group."
  type        = number
  default     = 7
}

variable "spacelift_api_credentials" {
  description = <<EOF
  Spacelift API credentials. This is used to authenticate the autoscaler and lifecycle manager with Spacelift. The credentials are stored in AWS Secrets Manager and SSM.
  - api_key_id: (mandatory) The ID of the Spacelift API key to use by the launcher.
  - api_key_secret: (mandatory) The secret corresponding to the Spacelift API key to use by the launcher.
  - api_key_endpoint: (mandatory) The full URL of the Spacelift API endpoint to use by the launcher. Example: https://mycorp.app.spacelift.io
  EOF
  sensitive   = true
  type = object({
    api_key_id       = string
    api_key_secret   = string
    api_key_endpoint = string
  })
  default = null
}