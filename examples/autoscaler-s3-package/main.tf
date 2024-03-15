data "aws_vpc" "this" {
  default = true
}

data "aws_security_group" "this" {
  name   = "default"
  vpc_id = data.aws_vpc.this.id
}

data "aws_subnets" "this" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
}

#### Spacelift worker pool ####

module "this" {
  source = "../../"

  configuration              = <<-EOT
    export SPACELIFT_TOKEN="<token-here>"
    export SPACELIFT_POOL_PRIVATE_KEY="<private-key-here>"
  EOT
  security_groups            = [data.aws_security_group.this.id]
  spacelift_api_key_endpoint = var.spacelift_api_key_endpoint
  spacelift_api_key_id       = var.spacelift_api_key_id
  spacelift_api_key_secret   = var.spacelift_api_key_secret
  vpc_subnets                = data.aws_subnets.this.ids
  worker_pool_id             = var.worker_pool_id

  enable_autoscaling = true
  autoscaler_s3_package = {
    bucket = aws_s3_bucket.autoscaler_binary.id
    key    = aws_s3_object.autoscaler_binary.id
  }
}
