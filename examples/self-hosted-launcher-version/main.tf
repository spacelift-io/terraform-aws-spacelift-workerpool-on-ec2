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
      TestCase = "SelfHostedLauncherVersion"
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

module "this" {
  source = "../../"

  worker_pool_id = random_string.worker_pool_id.id

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

  worker_comms_url = "https://spacelift.example.com"

  # The launcher for this self-hosted version is downloaded from
  # https://downloads.spacelift.io/self-hosted/v6.4.3/ and verified with GPG on boot,
  # so there is no binaries bucket to upload it to.
  selfhosted_configuration = {
    launcher_version = "v6.4.3"
  }

  manage_log_groups = false
}
