# Log group names are hardcoded to match the awslogs agent configuration in the
# Spacelift worker AMI (https://github.com/spacelift-io/spacelift-worker-image).

resource "aws_cloudwatch_log_group" "spacelift_info" {
  name                        = "spacelift-info.log"
  retention_in_days           = var.cloudwatch_log_group_retention
  kms_key_id                  = var.cloudwatch_kms_key_id
  skip_destroy                = var.cloudwatch_skip_destroy
  deletion_protection_enabled = var.cloudwatch_deletion_protection_enabled
  log_group_class             = var.cloudwatch_log_group_class
  tags                        = var.additional_tags
}

resource "aws_cloudwatch_log_group" "spacelift_errors" {
  name                        = "spacelift-errors.log"
  retention_in_days           = var.cloudwatch_log_group_retention
  kms_key_id                  = var.cloudwatch_kms_key_id
  skip_destroy                = var.cloudwatch_skip_destroy
  deletion_protection_enabled = var.cloudwatch_deletion_protection_enabled
  log_group_class             = var.cloudwatch_log_group_class
  tags                        = var.additional_tags
}
