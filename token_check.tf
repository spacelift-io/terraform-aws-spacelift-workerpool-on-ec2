resource "null_resource" "token_check" {
  triggers = {
    keeper = base64sha256("${jsonencode(var.secure_env_vars)}-${var.configuration}")
  }

  lifecycle {
    precondition {
      condition     = length(keys(var.secure_env_vars)) > 0 || var.configuration != ""
      error_message = "Either var.secure_env_vars or var.configuration must be set"
    }
  }
}