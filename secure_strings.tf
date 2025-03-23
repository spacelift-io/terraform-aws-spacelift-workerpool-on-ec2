locals {
  secure_env_vars_exports = join(
    "\n",
    [
      for key, _ in var.secure_env_vars : "export ${key}=$(echo $SECRET_VALUE | jq -r '.${key}')"
    ]
  )
  secure_env_vars = "export SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id ${local.base_name}-secret --query SecretString --output text)\n${local.secure_env_vars_exports}"
}

resource "aws_secretsmanager_secret" "this" {
  name = "${local.base_name}-secret"

  kms_key_id              = var.secure_env_vars_kms_key_id
  recovery_window_in_days = 0 # Force deletion without recovery window
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = jsonencode(var.secure_env_vars)
}
