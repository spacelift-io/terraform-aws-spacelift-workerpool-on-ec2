locals {
  secure_strings_count = length(keys(var.secure_strings)) > 0 ? 1 : 0
  secure_strings_exports = local.secure_strings_count > 0 ? join(
    "\n",
    [
      for key, _ in var.secure_strings : "export ${key}=$(aws secretsmanager get-secret-value --secret-id ${local.base_name}-secret --query SecretString --output text | jq -r '.${key}')"
    ]
  ) : ""
}

resource "aws_secretsmanager_secret" "this" {
  count = local.secure_strings_count
  name  = "${local.base_name}-secret"

  kms_key_id = var.secure_strings_kms_key_id
}

resource "aws_secretsmanager_secret_version" "this" {
  count         = local.secure_strings_count
  secret_id     = aws_secretsmanager_secret.this[count.index].id
  secret_string = jsonencode(var.secure_strings)
}