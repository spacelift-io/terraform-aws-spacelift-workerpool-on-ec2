import {
  for_each = var.import_cloudwatch_log_groups ? local.log_groups : toset([])
  to       = aws_cloudwatch_log_group.this[each.key]
  id       = each.key
}
