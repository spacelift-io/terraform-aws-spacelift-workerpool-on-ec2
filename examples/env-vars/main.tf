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
      TestCase = "env-vars"
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
  length           = 26
  numeric          = true
  special          = true
  override_special = "ABCDEFGHJKMNPQRSTVWXYZ"
  lower            = false
  upper            = false
}

#### Spacelift worker pool ####

module "this" {
  source = "../../"

  worker_pool_id = random_string.worker_pool_id.id

  # Mix of plain and sensitive env_vars entries.
  env_vars = {
    # Plain value — passed as-is in user data and directly as a Lambda env var.
    LOG_LEVEL = {
      value = "debug"
    }
    # Sensitive values — redacted in plan output, stored in Secrets Manager for
    # EC2 workers and as individual Secrets Manager secrets for Lambda functions.
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

  manage_log_groups = false
}
