terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

module "this" {
  source = "../../"

  worker_pool_id = "test"
}
