# Log group names are hardcoded to match the awslogs agent configuration in the
# Spacelift worker AMI (https://github.com/spacelift-io/spacelift-worker-image).

locals {
  log_groups = toset(["spacelift-info.log", "spacelift-errors.log"])
}

resource "aws_cloudwatch_log_group" "this" {
  for_each = local.log_groups

  name              = each.key
  retention_in_days = var.cloudwatch_log_group_retention
  kms_key_id        = var.cloudwatch_kms_key_id
  log_group_class   = var.cloudwatch_log_group_class
  tags              = var.additional_tags
}
