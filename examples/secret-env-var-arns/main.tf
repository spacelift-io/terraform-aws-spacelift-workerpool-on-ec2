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
      TestCase = "secret-env-var-arns"
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

resource "random_pet" "secret" {
  length = 4
}

# A pre-existing secret whose value Terraform never reads.
# The ARN is resource-computed (unknown at plan time), which exercises the
# plan-time safety of secret_env_var_arns.
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${random_pet.secret.id}-db-password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = "supersecret"
}

#### Spacelift worker pool ####

module "this" {
  source = "../../"

  worker_pool_id = random_string.worker_pool_id.id

  # Sensitive values stored in Secrets Manager by the module.
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

  # Reference an existing secret by ARN. Terraform never reads the value.
  # EC2 workers fetch it at startup; Lambda functions receive DB_PASSWORD_SECRET_ARN
  # and use the AWS Parameters and Secrets Lambda Extension to resolve it at runtime.
  secret_env_var_arns = {
    DB_PASSWORD = aws_secretsmanager_secret.db_password.arn
  }

  security_groups = [data.aws_security_group.this.id]
  vpc_subnets     = data.aws_subnets.this.ids

  autoscaling_vpc_sg_ids  = [data.aws_security_group.this.id]
  autoscaling_vpc_subnets = data.aws_subnets.this.ids
  autoscaling_configuration = {
    max_create          = 2
    max_terminate       = 2
    architecture        = "amd64"
    schedule_expression = "rate(1 minute)"
    timeout             = 60
  }
  spacelift_api_credentials = {
    api_key_endpoint = var.spacelift_api_key_endpoint
    api_key_id       = var.spacelift_api_key_id
    api_key_secret   = var.spacelift_api_key_secret
  }

  manage_log_groups = false
}
