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
      TestCase = "arm64"
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

#### Spacelift worker pool ####

module "this" {
  source = "../../"

  configuration = <<-EOT
    export SPACELIFT_SENSITIVE_OUTPUT_UPLOAD_ENABLED=true
  EOT
  secure_env_vars = {
    SPACELIFT_TOKEN            = "<token-here>"
    SPACELIFT_POOL_PRIVATE_KEY = "<private-key-here>"
  }
  ami_id = data.aws_ami.this.id
  # t4g.micro is just for using the random provider and a few resources.
  # If you are using more than a few resources as well as memory intensive providers it's recommended to use a t4g.medium or at least a t4g.small
  # https://docs.spacelift.io/concepts/worker-pools#hardware-recommendations
  ec2_instance_type = "t4g.micro"
  security_groups   = [data.aws_security_group.this.id]
  vpc_subnets       = data.aws_subnets.this.ids
  worker_pool_id    = var.worker_pool_id
}
