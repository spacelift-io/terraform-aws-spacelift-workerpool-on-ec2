terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.6"
    }

    random = { source = "hashicorp/random" }
  }
}

provider "aws" {
  region = local.region
}

locals {
  region   = "eu-west-1"
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "this" {
  source = "../../"

  configuration   = ""
  security_groups = [module.vpc.default_security_group_id]
  vpc_subnets     = module.vpc.private_subnets
  worker_pool_id  = random_pet.this.id
}

################################################################################
# Supporting resources
################################################################################

data "aws_availability_zones" "available" {}
resource "random_pet" "this" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = random_pet.this.id
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
}
