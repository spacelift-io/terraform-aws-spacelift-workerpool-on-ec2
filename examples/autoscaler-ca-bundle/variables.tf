variable "spacelift_api_key_id" {
  type        = string
  description = "ID of the Spacelift API key to use"
}

variable "spacelift_api_key_secret" {
  type        = string
  sensitive   = true
  description = "Secret corresponding to the Spacelift API key to use"
}

variable "spacelift_api_key_endpoint" {
  type        = string
  description = "Full URL of the Spacelift API endpoint to use, eg. https://demo.app.spacelift.io"
}

variable "ca_bundle" {
  type        = string
  description = "Base64-encoded PEM certificate or certificate chain for the autoscaler to trust when connecting to the Spacelift API. Example: base64encode(file(\"ca.pem\"))."
}
