locals {
  # env_vars entries with a plain/sensitive value — stored in the Secrets Manager bundle for EC2 workers
  env_vars_with_value = {
    for name, cfg in var.env_vars :
    name => cfg.value
    if cfg.value != null
  }

  # ARNs for IAM policy and user data come directly from var.secret_env_var_arns
  env_vars_secret_arns = values(var.secret_env_var_arns)

  # User data lines that fetch each secret_env_var_arns entry at EC2 startup
  env_vars_secret_arn_exports = join("\n", [
    for name, arn in var.secret_env_var_arns :
    "export ${name}=$(aws secretsmanager get-secret-value --secret-id ${arn} --query SecretString --output text)"
  ])

  byo_secretsmanager = var.byo_secretsmanager != null

  # Derived from the env_vars keys, never from the values. Values may come from a resource created in
  # the same run (e.g. spacelift_worker_pool.this.config), which makes them unknown at plan time — and
  # `cfg.value != null` on an unknown value is itself unknown, so anything filtered that way cannot
  # drive count/for_each ("The count value depends on resource attributes that cannot be determined
  # until apply"). Map keys are always known, so counting entries keeps the plan resolvable.
  has_secure_env_vars = length(var.env_vars) > 0 || local.byo_secretsmanager

  secret_name     = local.byo_secretsmanager ? var.byo_secretsmanager.name : "${local.base_name}-secret"
  secret_iterator = local.byo_secretsmanager ? { for i in var.byo_secretsmanager.keys : i => "BYO" } : local.env_vars_with_value

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
It is highly recommended to use the 'env_vars' parameter to store sensitive information.
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
  secret_string = jsonencode(local.env_vars_with_value)
}
