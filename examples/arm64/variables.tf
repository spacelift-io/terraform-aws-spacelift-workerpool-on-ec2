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

variable "worker_pool_id" {
  type        = string
  description = "ID (ULID) of the the worker pool."
}

variable "autoscaler_version" {
  type    = string
  default = "latest"
}