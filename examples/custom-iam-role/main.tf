terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "<5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
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

resource "random_pet" "this" {}

resource "aws_iam_role" "this" {
  name = random_pet.this.id

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AutoScalingReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]
}

#### Spacelift worker pool ####

module "this" {
  source = "../../"

  configuration   = <<-EOT
    export SPACELIFT_TOKEN="<token-here>"
    export SPACELIFT_POOL_PRIVATE_KEY="<private-key-here>"
  EOT
  iam_role_arn    = aws_iam_role.this.arn
  security_groups = [data.aws_security_group.this.id]
  vpc_subnets     = data.aws_subnets.this.ids
  worker_pool_id  = random_pet.this.id
  spacelift_api_key_id = var.spacelift_api_key_id
  spacelift_api_key_secret = var.spacelift_api_key_secret
  spacelift_api_key_endpoint = var.spacelift_api_key_endpoint
  local_path = var.local_path
}
