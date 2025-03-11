locals {
  ami_owner_ids = {
    aws        = "643313122712"
    aws-us-gov = "092348861888"
  }
}

data "aws_ami" "this" {
  most_recent = true
  name_regex  = "^spacelift-\\d{10}-x86_64$"
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
    values = ["x86_64"]
  }
}
