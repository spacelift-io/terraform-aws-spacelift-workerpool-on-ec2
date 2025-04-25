variable "autoscaling_configuration" {
  type = object({
    api_key_id          = string
    api_key_secret      = string
    api_key_endpoint    = string
    version             = optional(string)
    architecture        = optional(string)
    schedule_expression = optional(string)
    max_create          = optional(number)
    max_terminate       = optional(number)
    timeout             = optional(number)
    s3_package = optional(object({
      bucket         = string
      key            = string
      object_version = optional(string)
    }))
  })
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

variable "cloudwatch_log_group" {
  description = "Object of inputs for the autoscaler cloudwatch log group."
  type = object({
    retention_in_days = optional(number, 7)
  })
  nullable = false
  default  = {}
}

variable "is_managed" {
  description = "If this module is being used and deployed via spacelift"
  type        = bool
  default     = true
}
