locals {
  byo_ssm_creds_supplied = alltrue([
    local.byo_ssm,
    can(var.spacelift_api_credentials.api_key_endpoint),
    can(var.spacelift_api_credentials.api_key_id),
  ])

  generated_ssm_creds_supplied = alltrue([
    !local.byo_ssm,
    can(var.spacelift_api_credentials.api_key_endpoint),
    can(var.spacelift_api_credentials.api_key_id),
    can(var.spacelift_api_credentials.api_key_secret),
  ])
}

resource "validation_error" "env_vars_or_configuration" {
  condition = !local.has_secure_env_vars && length(var.secret_env_var_arns) == 0 && var.configuration == ""
  summary   = "Either var.env_vars, var.byo_secretsmanager, or var.configuration must be set"
  details   = <<EOT
You must supply either 'env_vars', 'var.byo_secretsmanager' or 'configuration' to the module.
EOT
}

resource "validation_error" "autoscaler_requires_api_token" {
  condition = local.autoscaling_enabled && !(local.generated_ssm_creds_supplied || local.byo_ssm_creds_supplied)
  summary   = "Spacelift API token is required for autoscaler"
  details   = <<EOT
The autoscaler requires api credentials to be passed in the 'spacelift_api_credentials' variable or var.byo_ssm provided.
EOT
}

resource "validation_error" "lifecycle_manager_requires_api_token" {
  condition = local.lifecycle_manager_enabled && !(local.generated_ssm_creds_supplied || local.byo_ssm_creds_supplied)
  summary   = "Spacelift API token is required for instance refresh support"
  details   = <<EOT
The instance refresh functionality requires api credentials to be passed in the 'spacelift_api_credentials' variable or var.byo_ssm provided.
EOT
}

