resource "null_resource" "token_check" {
  triggers = {
    keeper = base64sha256("${jsonencode(var.secure_strings)}-${var.configuration}")
  }

  lifecycle {
    precondition {
      condition     = length(keys(var.secure_strings)) > 0 || var.configuration != ""
      error_message = "Either var.secure_strings or var.configuration must be set"
    }
  }
}