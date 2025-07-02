terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }

    validation = {
      source  = "tlkamp/validation"
      version = ">= 1.0.0"
    }
  }
}
