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

resource "validation_error" "poll_requires_url" {
  condition = var.worker_comms_protocol == "poll" && var.worker_comms_url == null
  summary   = "HTTP long-poll requires a worker communication URL"
  details   = <<EOT
'worker_comms_url' must be set when 'worker_comms_protocol' is "poll". Use https://app.spacelift.io for EU SaaS, https://app.us.spacelift.io for US SaaS, or the base URL of your self-hosted or FedRAMP Spacelift server. To temporarily remain on MQTT, set 'worker_comms_protocol' to "mqtt".
EOT
}

resource "validation_error" "user_data_too_large" {
  condition = length(local.user_data) > 16384
  summary   = "The worker user data is larger than 16 KB"
  details   = <<EOT
EC2 limits user data to 16 KB and this configuration generates ${length(local.user_data)} bytes. The biggest contributors are usually 'ca_bundle' or 'selfhosted_configuration.ca_certificates', 'pre_launch_user_data' and 'configuration'. Move large CA bundles or scripts to S3 ('selfhosted_configuration.load_custom_certs') or into a custom AMI.
EOT
}
