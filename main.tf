locals {
  worker_pool_id = var.worker_pool_name == null ? var.worker_pool_id : var.worker_pool_name
  base_name = var.base_name == null ? "sp5ft-${local.worker_pool_id}" : var.base_name
}
