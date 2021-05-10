terraform {
  required_providers {
    aws    = { source = "hashicorp/aws" }
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

data "aws_subnet_ids" "this" {
  vpc_id = data.aws_vpc.this.id
}

resource "random_pet" "this" {}

module "this" {
  source = "../../"

  configuration   = ""
  security_groups = [data.aws_security_group.this.id]
  vpc_subnets     = data.aws_subnet_ids.this.ids
  worker_pool_id  = random_pet.this.id
}
