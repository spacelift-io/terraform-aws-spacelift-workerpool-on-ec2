# get info about selected instance type
data "aws_ec2_instance_type" "spacelift" {
  instance_type = var.ec2_instance_type
}

# get list of spacelift AMI ids starting with the newest
data "aws_ami_ids" "spacelift" {
  sort_ascending = false
  name_regex     = "^spacelift-\\d{10}-(arm64|x86_64)$"
  owners         = ["643313122712"]

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "architecture"
    # get ami architecture based on selected instance type (arm64 or x86_64).
    values = [for arch in data.aws_ec2_instance_type.spacelift.supported_architectures : arch if can(regex("(arm64|x86_64)$", arch))]
  }

  lifecycle {
    # Check if Spacelift AMI exists in current region. Spacelift AMIs are not replicated for all regions.
    postcondition {
      condition     = coalesce(var.ami_id, try(self.ids[0], "ami_not_found")) != "ami_not_found"
      error_message = "No Spacelift AMI found in current region '${data.aws_region.this.name}'. Use 'var.ami_id' instead to provide an existing Spacelift AMI."
    }
  }
}
