locals {
  base_name                               = var.base_name == null ? "sp5ft-${var.worker_pool_id}" : var.base_name
  autoscaling_enabled                     = var.autoscaling_configuration == null ? false : true
  lifecycle_manager_enabled               = var.instance_refresh != null ? true : false
  autoscaler_or_lifecycle_manager_enabled = local.autoscaling_enabled || local.lifecycle_manager_enabled

  byo_ssm            = var.byo_ssm != null
  generated_ssm_name = "/${local.base_name}/api-secret-${var.worker_pool_id}"
  ssm_name           = local.byo_ssm ? var.byo_ssm.name : local.generated_ssm_name
  ssm_arn = (local.byo_ssm ? var.byo_ssm.arn : (local.autoscaler_or_lifecycle_manager_enabled ?
  aws_ssm_parameter.spacelift_api_key_secret[0].arn : "DISABLED"))
}

resource "aws_ssm_parameter" "spacelift_api_key_secret" {
  count = local.autoscaler_or_lifecycle_manager_enabled && !local.byo_ssm ? 1 : 0
  name  = local.generated_ssm_name
  type  = "SecureString"
  value = var.spacelift_api_credentials.api_key_secret
  tags  = var.additional_tags
}

module "autoscaler" {
  count  = local.autoscaling_enabled ? 1 : 0
  source = "./autoscaler"

  additional_tags                  = var.additional_tags
  api_key_ssm_parameter_arn        = local.ssm_arn
  api_key_ssm_parameter_name       = local.ssm_name
  auto_scaling_group_arn           = module.asg.autoscaling_group_arn
  autoscaling_configuration        = var.autoscaling_configuration
  aws_partition_dns_suffix         = data.aws_partition.current.dns_suffix
  aws_region                       = data.aws_region.this.region
  base_name                        = local.base_name
  cloudwatch_log_group_retention   = var.cloudwatch_log_group_retention
  spacelift_api_credentials        = var.spacelift_api_credentials
  iam_permissions_boundary         = var.iam_permissions_boundary
  worker_pool_id                   = var.worker_pool_id
  spacelift_vpc_subnet_ids         = var.autoscaling_vpc_subnets
  spacelift_vpc_security_group_ids = var.autoscaling_vpc_sg_ids
  tracing_mode                     = var.autoscaling_tracing_mode
}

module "lifecycle_manager" {
  count  = local.lifecycle_manager_enabled ? 1 : 0
  source = "./lifecycle_manager"

  additional_tags                = var.additional_tags
  api_key_ssm_parameter_arn      = local.ssm_arn
  api_key_ssm_parameter_name     = local.ssm_name
  auto_scaling_group_arn         = module.asg.autoscaling_group_arn
  cloudwatch_log_group_retention = var.cloudwatch_log_group_retention
  aws_partition_dns_suffix       = data.aws_partition.current.dns_suffix
  aws_region                     = data.aws_region.this.region
  base_name                      = local.base_name
  iam_permissions_boundary       = var.iam_permissions_boundary
  worker_pool_id                 = var.worker_pool_id
  spacelift_api_credentials      = var.spacelift_api_credentials
}

moved {
  from = aws_iam_role.autoscaler
  to   = module.autoscaler[0].aws_iam_role.autoscaler
}

moved {
  from = aws_iam_role_policy.autoscaler
  to   = module.autoscaler[0].aws_iam_role_policy.autoscaler
}

moved {
  from = aws_lambda_function.autoscaler
  to   = module.autoscaler[0].aws_lambda_function.autoscaler
}

moved {
  from = null_resource.download
  to   = module.autoscaler[0].null_resource.download
}

moved {
  from = aws_cloudwatch_event_rule.scheduling
  to   = module.autoscaler[0].aws_cloudwatch_event_rule.scheduling
}

moved {
  from = aws_cloudwatch_event_target.scheduling
  to   = module.autoscaler[0].aws_cloudwatch_event_target.scheduling
}

moved {
  from = aws_lambda_permission.allow_cloudwatch_to_call_lambda
  to   = module.autoscaler[0].aws_lambda_permission.allow_cloudwatch_to_call_lambda
}

moved {
  from = aws_cloudwatch_log_group.log_group
  to   = module.autoscaler[0].aws_cloudwatch_log_group.log_group
}
