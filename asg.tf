data "aws_region" "this" {}

locals {
  user_data_head = <<EOF
#!/bin/bash

spacelift () {(
set -e
  EOF

  user_data_tail = <<EOF
currentArch=$(uname -m)

if [[ "$currentArch" != "x86_64" && "$currentArch" != "aarch64" ]]; then
  echo "Unsupported architecture: $currentArch" >> /var/log/spacelift/error.log
  return 1
fi

baseURL="https://downloads.${var.domain_name}/spacelift-launcher"
binaryURL=$(printf "%s-%s" "$baseURL" "$currentArch")
shaSumURL=$(printf "%s-%s_%s" "$baseURL" "$currentArch" "SHA256SUMS")
shaSumSigURL=$(printf "%s-%s_%s" "$baseURL" "$currentArch" "SHA256SUMS.sig")

echo "Downloading Spacelift launcher" >> /var/log/spacelift/info.log
curl "$binaryURL" --output /usr/bin/spacelift-launcher 2>>/var/log/spacelift/error.log

echo "Importing public GPG key" >> /var/log/spacelift/info.log
curl https://keys.openpgp.org/vks/v1/by-fingerprint/175FD97AD2358EFE02832978E302FB5AA29D88F7 | gpg --import 2>>/var/log/spacelift/error.log

echo "Downloading Spacelift launcher checksum file and signature" >> /var/log/spacelift/info.log
curl "$shaSumURL" --output spacelift-launcher_SHA256SUMS 2>>/var/log/spacelift/error.log
curl "$shaSumSigURL" --output spacelift-launcher_SHA256SUMS.sig 2>>/var/log/spacelift/error.log

echo "Verifying checksum signature..." >> /var/log/spacelift/info.log
gpg --verify spacelift-launcher_SHA256SUMS.sig 1>>/var/log/spacelift/info.log 2>>/var/log/spacelift/error.log

retStatus=$?
if [ $retStatus -eq 0 ]; then
    echo "OK\!" >> /var/log/spacelift/info.log
else
    return $retStatus
fi

CHECKSUM=$(cut -f 1 -d ' ' spacelift-launcher_SHA256SUMS)
rm spacelift-launcher_SHA256SUMS spacelift-launcher_SHA256SUMS.sig
LAUNCHER_SHA=$(sha256sum /usr/bin/spacelift-launcher | cut -f 1 -d ' ')

echo "Verifying launcher binary..." >> /var/log/spacelift/info.log
if [[ "$CHECKSUM" == "$LAUNCHER_SHA" ]]; then
  echo "OK\!" >> /var/log/spacelift/info.log
else
  echo "Checksum and launcher binary hash did not match" >> /var/log/spacelift/error.log
  return 1
fi

echo "Making the Spacelift launcher executable" >> /var/log/spacelift/info.log
chmod 755 /usr/bin/spacelift-launcher 2>>/var/log/spacelift/error.log

echo "Retrieving EC2 instance id and AMI id" >> /var/log/spacelift/info.log
export SPACELIFT_METADATA_instance_id=$(ec2-metadata --instance-id | cut -d ' ' -f2)
export SPACELIFT_METADATA_ami_id=$(ec2-metadata --ami-id | cut -d ' ' -f2)

echo "Retrieving EC2 ASG ID" >> /var/log/spacelift/info.log
export SPACELIFT_METADATA_asg_id=$(aws autoscaling --region=${data.aws_region.this.name} describe-auto-scaling-instances --instance-ids $SPACELIFT_METADATA_instance_id | jq -r '.AutoScalingInstances[0].AutoScalingGroupName')

echo "Starting the Spacelift binary" >> /var/log/spacelift/info.log
/usr/bin/spacelift-launcher 1>>/var/log/spacelift/info.log 2>>/var/log/spacelift/error.log
)}

spacelift
echo "Powering off in ${var.poweroff_delay} seconds" >> /var/log/spacelift/error.log
sleep ${var.poweroff_delay}
poweroff
  EOF
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.0"

  name = local.namespace

  iam_instance_profile_arn = aws_iam_instance_profile.this.arn
  image_id                 = var.ami_id != "" ? var.ami_id : data.aws_ami.this.id
  instance_type            = var.ec2_instance_type
  security_groups          = var.security_groups
  enable_monitoring        = var.enable_monitoring
  instance_refresh         = var.instance_refresh

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = var.volume_encryption
        kms_key_id            = var.volume_encryption ? var.volume_encryption_kms_key_id : null
        volume_size           = var.volume_size
        volume_type           = "gp3"
      }
    }
  ]

  # Auto scaling group
  wait_for_capacity_timeout = 0

  termination_policies = [
    "OldestLaunchTemplate", # First look at the oldest launch template.
    "OldestInstance",       # When that has not changed, kill oldest instances first.
  ]

  enabled_metrics     = var.enabled_metrics
  vpc_zone_identifier = var.vpc_subnets

  health_check_grace_period = 30
  health_check_type         = "EC2"
  default_cooldown          = 10

  min_size = var.min_size
  max_size = var.max_size

  # Do not manage desired capacity!
  desired_capacity = null

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = var.disable_container_credentials ? 1 : 2
  }

  # User data
  user_data = base64encode(
    join("\n", [
      local.user_data_head,
      var.configuration,
      local.user_data_tail,
    ])
  )

  tags = merge(var.additional_tags,
    {
      "WorkerPoolID" : var.worker_pool_id
    }
  )
}
