terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "< 6.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      TfModule = "terraform-aws-spacelift-workerpool-on-ec2"
      TestCase = "CustomIAMRole"
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

data "aws_partition" "current" {}

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
          Service = "ec2.${data.aws_partition.current.dns_suffix}"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attachment" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AutoScalingReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])
  role       = aws_iam_role.this.name
  policy_arn = each.key
}

#### Spacelift worker pool ####

module "this" {
  source = "../../"

  secure_env_vars = {
    SPACELIFT_TOKEN            = "<token-here>"
    SPACELIFT_POOL_PRIVATE_KEY = "<private-key-here>"
  }
  create_iam_role      = false
  custom_iam_role_name = aws_iam_role.this.name
  security_groups      = [data.aws_security_group.this.id]
  vpc_subnets          = data.aws_subnets.this.ids
  worker_pool_id       = var.worker_pool_id
}
