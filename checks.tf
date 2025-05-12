resource "validation_error" "secure_env_vars_or_configuration" {
  condition = !local.has_secure_env_vars && var.configuration == ""
  summary   = "Either var.secure_env_vars or var.configuration must be set"
  details   = <<EOT
You must supply either 'secure_env_vars' or 'configuration' to the module.
EOT
}

resource "validation_error" "autoscaler_requires_api_token" {
  condition = var.autoscaling_configuration != null && var.spacelift_api_credentials == null
  summary   = "Spacelift API token is required for autoscaler"
  details   = <<EOT
The autoscaler requires api credentials to be passed in the 'spacelift_api_credentials' variable.
EOT
}

resource "validation_error" "lifecycle_manager_requires_api_token" {
  condition = local.lifecycle_manager_enabled && var.spacelift_api_credentials == null
  summary   = "Spacelift API token is required for instance refresh support"
  details   = <<EOT
The instance refresh functionality requires api credentials to be passed in the 'spacelift_api_credentials' variable.
EOT
}