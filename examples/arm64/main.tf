terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "<5.0"
    }

    random = { source = "hashicorp/random" }
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

data "aws_ami" "this" {
  most_recent = true
  name_regex  = "^spacelift-\\d{10}-arm64$"
  owners      = ["643313122712"]

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

resource "random_pet" "this" {}

#### Spacelift worker pool ####

module "this" {
  source = "../../"

  configuration     = <<-EOT
    export SPACELIFT_TOKEN="<token-here>"
    export SPACELIFT_POOL_PRIVATE_KEY="<private-key-here>"
  EOT
  security_groups   = [data.aws_security_group.this.id]
  vpc_subnets       = data.aws_subnets.this.ids
  worker_pool_id    = random_pet.this.id
  ami_id            = data.aws_ami.this.id
  ec2_instance_type = "t4g.micro"
}
