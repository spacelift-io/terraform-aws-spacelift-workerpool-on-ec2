locals {
  ca_bundle = var.ca_bundle != null ? var.ca_bundle : try(var.autoscaling_configuration.ca_bundle, null)

  # EC2 workers install ca_bundle into the OS trust store, falling back to ca_certificates.
  effective_ca_certificates = local.ca_bundle != null ? [base64decode(local.ca_bundle)] : (
    var.selfhosted_configuration.ca_certificates == null ? [] : var.selfhosted_configuration.ca_certificates
  )

  # Lambdas fetch this at runtime. Named "unified" as it becomes the single bundle in v8.
  unified_secret_enabled = local.ca_bundle != null && local.autoscaler_or_lifecycle_manager_enabled
  ca_bundle_secret_arn   = local.unified_secret_enabled ? aws_secretsmanager_secret.unified[0].arn : null
}

resource "aws_secretsmanager_secret" "unified" {
  count = local.unified_secret_enabled ? 1 : 0

  name                    = "${local.base_name}-unified-secret"
  recovery_window_in_days = 0
  tags                    = var.additional_tags
}

resource "aws_secretsmanager_secret_version" "unified" {
  count = local.unified_secret_enabled ? 1 : 0

  secret_id     = aws_secretsmanager_secret.unified[0].id
  secret_string = local.ca_bundle
}
