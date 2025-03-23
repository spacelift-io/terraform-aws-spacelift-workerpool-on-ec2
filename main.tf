locals {
  base_name = var.base_name == null ? "sp5ft-${var.worker_pool_id}" : var.base_name
}

module "autoscaler" {
  count  = var.autoscaling_configuration == null ? 0 : 1
  source = "./autoscaler"

  additional_tags           = var.additional_tags
  auto_scaling_group_arn    = module.asg.autoscaling_group_arn
  autoscaling_configuration = var.autoscaling_configuration
  aws_partition_dns_suffix  = data.aws_partition.current.dns_suffix
  aws_region                = data.aws_region.this.name
  base_name                 = local.base_name
  iam_permissions_boundary  = var.iam_permissions_boundary
  worker_pool_id            = var.worker_pool_id
}
