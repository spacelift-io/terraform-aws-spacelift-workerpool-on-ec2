terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }

    random = { source = "hashicorp/random" }
  }
}

# The provider region is used for authentication and for any lookups that
# don't set a provider explicitly. The worker pool is deployed to var.region below.
provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      TfModule = "terraform-aws-spacelift-workerpool-on-ec2"
      TestCase = "Region"
    }
  }
}

# Provider for the region the worker pool is deployed into. The VPC and subnet
# lookups below must run in that region, since the module uses those subnets.
provider "aws" {
  alias  = "worker_pool"
  region = "us-east-1"

  default_tags {
    tags = {
      TfModule = "terraform-aws-spacelift-workerpool-on-ec2"
      TestCase = "Region"
    }
  }
}

data "aws_vpc" "worker_pool" {
  provider = aws.worker_pool
  default  = true
}

data "aws_security_group" "worker_pool" {
  provider = aws.worker_pool
  name     = "default"
  vpc_id   = data.aws_vpc.worker_pool.id
}

data "aws_subnets" "worker_pool" {
  provider = aws.worker_pool
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.worker_pool.id]
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

module "this" {
  source = "../../"

  region         = "us-east-1"
  worker_pool_id = random_string.worker_pool_id.id

  worker_comms_url = "https://app.spacelift.io"

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

  security_groups = [data.aws_security_group.worker_pool.id]
  vpc_subnets     = data.aws_subnets.worker_pool.ids

  manage_log_groups = false
}
