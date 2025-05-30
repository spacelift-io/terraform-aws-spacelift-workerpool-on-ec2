locals {
  ami_owner_ids = {
    aws        = "643313122712"
    aws-us-gov = "092348861888"
  }

  archs = {
    amd64 = "x86_64"
    arm64 = "arm64"
  }
  arch = try(local.archs[var.autoscaling_configuration["architecture"]], "x86_64")
}

data "aws_ami" "this" {
  most_recent = true
  name_regex  = "^spacelift-\\d{10}-${local.arch}$"
  owners      = [local.ami_owner_ids[data.aws_partition.current.partition]]

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
    values = [local.arch]
  }
}
