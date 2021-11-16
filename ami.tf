data "aws_ami" "this" {
  most_recent = true
  name_regex  = "^spacelift-\\d{10}$"
  owners      = ["643313122712"]

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
