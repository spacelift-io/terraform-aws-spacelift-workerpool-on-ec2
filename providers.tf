terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.55.0"
    }

    validation = {
      source  = "tlkamp/validation"
      version = ">= 1.0.0"
    }
  }
}
