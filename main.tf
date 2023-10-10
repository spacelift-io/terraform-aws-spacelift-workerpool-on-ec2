locals {
  base_name = var.base_name == null ? "sp5ft-${var.worker_pool_id}" : var.base_name
}
