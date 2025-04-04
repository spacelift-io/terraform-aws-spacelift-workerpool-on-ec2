locals {
  ami_owner_ids = {
    aws        = "643313122712"
    aws-us-gov = "092348861888"
  }
}

data "aws_ami" "this" {
  count = var.ami_id == "" ? 1 : 0

  most_recent = true
  name_regex  = "^spacelift-\\d{10}-${var.ami_architecture}$"
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
    values = [var.ami_architecture]
  }
}
