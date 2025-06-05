terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "< 6.0"
    }

    random = { source = "hashicorp/random" }
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      TfModule = "terraform-aws-spacelift-workerpool-on-ec2"
      TestCase = "Autoscaler"
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
  # Use special and override special to allow only uppercase letters and numbers
  # but exclude I, L, O, and U as it does not conform to the regex used by Spacelift
  special          = true
  override_special = "ABCDEFGHJKMNPQRSTVWXYZ"
  lower            = false
  upper            = false
}

// This is just here for testing purposes.
resource "random_pet" "byo" {
  prefix = "byo"
  length = 8
}

resource "aws_secretsmanager_secret" "byo" {
  name = random_pet.byo.id
}

resource "aws_secretsmanager_secret_version" "byo" {
  secret_id = aws_secretsmanager_secret.byo.id
  secret_string = jsonencode({
    SPACELIFT_TOKEN            = "<token-here>"
    SPACELIFT_POOL_PRIVATE_KEY = "<private-key-here>"
  })
}

resource "aws_ssm_parameter" "byo" {
  name  = random_pet.byo.id
  type  = "SecureString"
  value = var.spacelift_api_key_secret
}

#### Spacelift worker pool ####

module "this" {
  source = "../../"

  security_groups = [data.aws_security_group.this.id]
  vpc_subnets     = data.aws_subnets.this.ids
  worker_pool_id  = random_string.worker_pool_id.id

  byo_secretsmanager = {
    name = aws_secretsmanager_secret.byo.name
    arn  = aws_secretsmanager_secret.byo.arn
    keys = [
      "SPACELIFT_TOKEN",
      "SPACELIFT_POOL_PRIVATE_KEY"
    ]
  }

  byo_ssm = {
    name = aws_ssm_parameter.byo.name
    arn  = aws_ssm_parameter.byo.arn
  }

  autoscaling_configuration = {
    max_create          = 5
    max_terminate       = 5
    architecture        = "arm64" # ~ 20% cheaper than amd64
    schedule_expression = "rate(1 minute)"
    timeout             = 60
  }

  spacelift_api_credentials = {
    api_key_endpoint = var.spacelift_api_key_endpoint
    api_key_id       = var.spacelift_api_key_id
  }

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      instance_warmup        = 60
      min_healthy_percentage = 50
      max_healthy_percentage = 100
    }
    triggers = ["tag"]
  }
}
