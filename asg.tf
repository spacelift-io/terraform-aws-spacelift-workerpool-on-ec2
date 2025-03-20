data "aws_region" "this" {}

locals {
  selfhosted_user_data = templatefile("${path.module}/user_data/selfhosted.tftpl", {
    custom_user_data               = join("\n", [local.secure_env_vars, var.configuration])
    run_launcher_as_spacelift_user = var.selfhosted_configuration.run_launcher_as_spacelift_user == null ? true : var.selfhosted_configuration.run_launcher_as_spacelift_user
    launcher_s3_uri                = var.selfhosted_configuration.s3_uri
    http_proxy_config              = var.selfhosted_configuration.http_proxy_config == null ? "" : var.selfhosted_configuration.http_proxy_config
    https_proxy_config             = var.selfhosted_configuration.https_proxy_config == null ? "" : var.selfhosted_configuration.https_proxy_config
    no_proxy_config                = var.selfhosted_configuration.no_proxy_config == null ? "" : var.selfhosted_configuration.no_proxy_config
    ca_certificates                = var.selfhosted_configuration.ca_certificates == null ? [] : var.selfhosted_configuration.ca_certificates
    region                         = data.aws_region.this.name
    power_off_on_error             = var.selfhosted_configuration.power_off_on_error == null ? true : var.selfhosted_configuration.power_off_on_error
  })

  saas_user_data = templatefile("${path.module}/user_data/saas.tftpl", {
    custom_user_data = join("\n", [local.secure_env_vars, var.configuration])
    domain_name      = var.domain_name
    poweroff_delay   = var.poweroff_delay
    region           = data.aws_region.this.name
  })
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 8.0"

  name = local.base_name

  iam_instance_profile_arn = aws_iam_instance_profile.this.arn
  image_id                 = var.ami_id != "" ? var.ami_id : data.aws_ami.this.id
  instance_type            = var.ec2_instance_type
  security_groups          = var.security_groups
  enable_monitoring        = var.enable_monitoring
  instance_refresh         = var.instance_refresh
  instance_market_options  = var.instance_market_options

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

  suspended_processes = var.enable_autoscaling ? [
    # Prevents the ASG from terminating instances for rebalancing between AZs, 
    # which triggered right after termination of instances by lambda
    "AZRebalance"
  ] : []

  user_data = base64encode(var.selfhosted_configuration.s3_uri == "" ? local.saas_user_data : local.selfhosted_user_data)

  tag_specifications = var.tag_specifications

  tags = merge(var.additional_tags,
    {
      "WorkerPoolID" : var.worker_pool_id
    }
  )
}
