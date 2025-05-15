locals {
  byo_secretsmanager  = var.byo_secretsmanager != null
  has_secure_env_vars = (var.secure_env_vars != null && length(var.secure_env_vars) > 0) || local.byo_secretsmanager

  secret_name     = local.byo_secretsmanager ? var.byo_secretsmanager.name : "${local.base_name}-secret"
  secret_iterator = local.byo_secretsmanager ? { for i in var.byo_secretsmanager.keys : i => "BYO" } : var.secure_env_vars

  secure_env_vars_exports = join(
    "\n",
    [
      for key, _ in local.secret_iterator : "export ${key}=$(echo $SECRET_VALUE | jq -r '.${key}')"
    ]
  )

  secure_env_vars = local.has_secure_env_vars ? "export SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id ${local.secret_name} --query SecretString --output text)\n${local.secure_env_vars_exports}" : ""
}

resource "validation_warning" "token_or_private_key_in_plaintext" {
  condition = strcontains(var.configuration, "export SPACELIFT_TOKEN") || strcontains(var.configuration, "export SPACELIFT_POOL_PRIVATE_KEY")
  summary   = "Detected sensitive environment variable in plaintext format"
  details   = <<EOT
The 'configuration' parameter seems to contain the 'SPACELIFT_TOKEN' or 'SPACELIFT_POOL_PRIVATE_KEY' environment variables.
These configuration values are injected in plaintext format into the user data script.
It is highly recommended to use the 'secure_env_vars' parameter to store sensitive information.
EOT
}

resource "aws_secretsmanager_secret" "this" {
  count = local.has_secure_env_vars && !local.byo_secretsmanager ? 1 : 0

  name                    = "${local.base_name}-secret"
  kms_key_id              = var.secure_env_vars_kms_key_id
  recovery_window_in_days = 0 # Force deletion without recovery window
  description             = "Holding secure environment variables for ${var.worker_pool_id} Spacelift worker pool"
  tags                    = var.additional_tags
}

resource "aws_secretsmanager_secret_version" "this" {
  count = local.has_secure_env_vars && !local.byo_secretsmanager ? 1 : 0

  secret_id     = aws_secretsmanager_secret.this[0].id
  secret_string = jsonencode(var.secure_env_vars)
}
