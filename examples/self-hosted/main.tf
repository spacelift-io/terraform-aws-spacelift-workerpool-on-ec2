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

#### Spacelift worker pool ####

module "this" {
  source = "../../"

  configuration              = <<-EOT
    export SPACELIFT_TOKEN="<token-here>"
    export SPACELIFT_POOL_PRIVATE_KEY="<private-key-here>"
  EOT
  security_groups            = [data.aws_security_group.this.id]
  spacelift_api_key_endpoint = var.spacelift_api_key_endpoint
  spacelift_api_key_id       = var.spacelift_api_key_id
  spacelift_api_key_secret   = var.spacelift_api_key_secret
  vpc_subnets                = data.aws_subnets.this.ids
  worker_pool_id             = var.worker_pool_id

  enable_autoscaling = false

  tag_specifications = [
    {
      resource_type = "instance"
      tags = {
        Name = "sp5ft-${var.worker_pool_id}"
      }
    },
    {
      resource_type = "volume"
      tags = {
        Name = "sp5ft-${var.worker_pool_id}"
      }
    },
    {
      resource_type = "network-interface"
      tags = {
        Name = "sp5ft-${var.worker_pool_id}"
      }
    }
  ]

  selfhosted_configuration = {
    s3_uri                         = "s3://example-bucketname1234/spacelift-launcher"
    run_launcher_as_spacelift_user = true
    http_proxy_config              = "http://proxy.example.com:3128"
    https_proxy_config             = "https://proxy.example.com:3128"
    no_proxy_config                = ".spacelift.io"
    ca_certificates = [<<-EOT
-----BEGIN CERTIFICATE-----
MIIBhTCCASsCFDEycCnpoCYvsElGGeGrNH1mhxx2MAoGCCqGSM49BAMCMEUxCzAJ
BgNVBAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5l
dCBXaWRnaXRzIFB0eSBMdGQwHhcNMjUwMzA3MTcyODI5WhcNMjYwMzA3MTcyODI5
WjBFMQswCQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwY
SW50ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcD
QgAEUdHbvH91M4hEL4V1pOXL8eobQoDT5L9nZh+5jmaNzPINun3IpofSwC6KxKzE
Jy9VCLzzJiFRUBkIGRShSeJnwDAKBggqhkjOPQQDAgNIADBFAiAEio4uC9+a1H4T
ca5cZMOavr6J9vWz5bJeWA91hyUcUQIhANV9ZlN/AzYo65rDDAXApyQBIzDSstzY
DjoEumHytQOs
-----END CERTIFICATE-----
EOT
    ]
    power_off_on_error = true
  }
}
