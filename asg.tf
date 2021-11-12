data "aws_region" "this" {}

locals {
  user_data_head = <<EOF
#!/bin/bash

spacelift () {(
set -e
  EOF

  user_data_tail = <<EOF
echo "Downloading Spacelift launcher" >> /var/log/spacelift/info.log
curl https://downloads.${var.domain_name}/spacelift-launcher --output /usr/bin/spacelift-launcher 2>>/var/log/spacelift/error.log

echo "Importing public GPG key" >> /var/log/spacelift/info.log
curl https://keys.openpgp.org/vks/v1/by-fingerprint/175FD97AD2358EFE02832978E302FB5AA29D88F7 | gpg --import 2>>/var/log/spacelift/error.log

echo "Downloading Spacelift launcher checksum file and signature" >> /var/log/spacelift/info.log
curl https://downloads.${var.domain_name}/spacelift-launcher_SHA256SUMS --output spacelift-launcher_SHA256SUMS 2>>/var/log/spacelift/error.log
curl https://downloads.${var.domain_name}/spacelift-launcher_SHA256SUMS.sig --output spacelift-launcher_SHA256SUMS.sig 2>>/var/log/spacelift/error.log

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

echo "Retrieving EC2 instance ID" >> /var/log/spacelift/info.log
export SPACELIFT_METADATA_instance_id=$(ec2-metadata --instance-id | cut -d ' ' -f2)

echo "Retrieving EC2 ASG ID" >> /var/log/spacelift/info.log
export SPACELIFT_METADATA_asg_id=$(aws autoscaling --region=${data.aws_region.this.name} describe-auto-scaling-instances --instance-ids $SPACELIFT_METADATA_instance_id | jq -r '.AutoScalingInstances[0].AutoScalingGroupName')

echo "Starting the Spacelift binary" >> /var/log/spacelift/info.log
/usr/bin/spacelift-launcher 1>>/var/log/spacelift/info.log 2>>/var/log/spacelift/error.log
)}

spacelift
echo "Powering off in 15 seconds" >> /var/log/spacelift/error.log
sleep 15
poweroff
  EOF
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 4.0"

  name    = local.namespace
  lc_name = local.namespace

  use_lc    = true
  create_lc = true

  iam_instance_profile_name = aws_iam_instance_profile.this.arn
  image_id                  = var.ami_id != "" ? var.ami_id : data.aws_ami.this.id
  instance_type             = var.ec2_instance_type
  placement_tenancy         = "default"
  security_groups           = var.security_groups

  root_block_device = [
    {
      encrypted   = var.volume_encryption
      volume_size = var.volume_size
      volume_type = "gp3"
    },
  ]

  # Auto scaling group
  wait_for_capacity_timeout = 0

  termination_policies = [
    "OldestLaunchConfiguration", # First look at the oldest launch configuration.
    "OldestInstance",            # When that has not changed, kill oldest instances first.
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

  tags        = var.tags
  tags_as_map = { "WorkerPoolID" : var.worker_pool_id }
}
