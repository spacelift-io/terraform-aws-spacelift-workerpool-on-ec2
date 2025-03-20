locals {
  secure_env_vars_count = length(keys(var.secure_env_vars)) > 0 ? 1 : 0
  secure_env_vars_exports = local.secure_env_vars_count > 0 ? join(
    "\n",
    [
      for key, _ in var.secure_env_vars : "export ${key}=$(echo $SECRET_VALUE | jq -r '.${key}')"
    ]
  ) : ""
  secure_env_vars = "export SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id ${local.base_name}-secret --query SecretString --output text)\n${local.secure_env_vars_exports}"
}

resource "aws_secretsmanager_secret" "this" {
  count = local.secure_env_vars_count
  name  = "${local.base_name}-secret"

  kms_key_id = var.secure_env_vars_kms_key_id
}

resource "aws_secretsmanager_secret_version" "this" {
  count         = local.secure_env_vars_count
  secret_id     = aws_secretsmanager_secret.this[count.index].id
  secret_string = jsonencode(var.secure_env_vars)
}