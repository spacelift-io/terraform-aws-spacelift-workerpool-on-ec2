terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }

    random = { source = "hashicorp/random" }
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      TfModule = "terraform-aws-spacelift-workerpool-on-ec2"
      TestCase = "network-interfaces"
    }
  }
}

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

resource "random_string" "worker_pool_id" {
  length  = 26
  numeric = true
  # Use special and override special to allow only uppercase letters and numbers
  # but exclude I, L, O, and U as it does not conform to the regex used by Spacelift
  special          = true
  override_special = "ABCDEFGHJKMNPQRSTVWXYZ"
  lower            = false
  upper            = false
}

#### Spacelift worker pool ####

# Example: use network_interfaces to enable associate_public_ip_address.
# security_groups can still be passed at the top level — the underlying
# autoscaling module merges them into each network interface entry.
module "this" {
  source = "../../"

  worker_pool_id = random_string.worker_pool_id.id

  configuration = <<-EOT
    export SPACELIFT_SENSITIVE_OUTPUT_UPLOAD_ENABLED=true
    export SPACELIFT_LAUNCHER_RUN_TIMEOUT=120m
  EOT
  env_vars = {
    SPACELIFT_TOKEN = {
      value     = "<token-here>"
      sensitive = true
    }
    SPACELIFT_POOL_PRIVATE_KEY = {
      value     = "<private-key-here>"
      sensitive = true
    }
  }

  security_groups = [data.aws_security_group.this.id]
  vpc_subnets     = data.aws_subnets.this.ids

  network_interfaces = [
    {
      associate_public_ip_address = true
      delete_on_termination       = true
    }
  ]

  manage_log_groups = false
}
