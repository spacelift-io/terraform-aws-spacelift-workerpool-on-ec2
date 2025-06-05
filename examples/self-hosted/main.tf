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
      TestCase = "SelfHosted"
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

resource "random_string" "worker_pool_id" {
  length           = 26
  numeric          = true
  # Use special and override special to allow only uppercase letters and numbers
  # but exclude I, L, O, and U as it does not conform to the regex used by Spacelift
  special          = true
  override_special = "ABCDEFGHJKMNPQRSTVWXYZ"
  lower            = false
  upper            = false
}

#### Spacelift worker pool ####

module "this" {
  source = "../../"

  secure_env_vars = {
    SPACELIFT_TOKEN            = "<token-here>"
    SPACELIFT_POOL_PRIVATE_KEY = "<private-key-here>"
  }
  security_groups = [data.aws_security_group.this.id]
  vpc_subnets     = data.aws_subnets.this.ids
  worker_pool_id  = random_string.worker_pool_id.id

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
