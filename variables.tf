variable "ami_id" {
  type        = string
  description = "ID of the Spacelift AMI. If left empty, the latest Spacelift AMI will be used."
  default     = ""
}

variable "byo_ssm" {
  type = object({
    name = string
    arn  = string
  })
  description = <<EOF
  Name and ARN of the SSM parameter to use for the autoscaler. If left empty, the parameter will be created for you.
  The parameter should only contain the Spacelift API key secret in plain text.
EOF
  default     = null
}

variable "byo_secretsmanager" {
  type = object({
    name = string
    arn  = string
    keys = list(string)
  })
  description = <<EOF
  Name and ARN of the Secrets Manager secret to use for the autoscaler and keys to export. If left empty, the secret will be created for you.
  The keys will be exported as environment variables in the format `export {key}=$(echo $SECRET_VALUE | jq -r '.{key}')`.
    The secret value must be a JSON object with the keys specified in the list. For example, if the list is ["key_1", "key_2"], the secret value must be:
    {
      "key_1": "value_1",
      "key_2": "value_2"
    }
EOF
  default     = null
}

variable "ami_architecture" {
  type        = string
  description = "Architecture of the Spacelift AMI. Currently, only x86_64 or arm64 are supported."
  default     = "x86_64"
  validation {
    condition     = contains(["x86_64", "arm64"], var.ami_architecture)
    error_message = "Currently, only x86_64 or arm64 are supported."
  }
}

variable "secure_env_vars" {
  type        = map(string)
  sensitive   = true
  description = <<EOF
    Secure env vars to be stored in Secrets Manager. Their values will be exported
    at run time as `export {key}={value}`. This allows you pass the token, private
    key, or any values securely.
EOF
  default     = {}
}


variable "configuration" {
  type        = string
  description = <<EOF
  Plain text user configuration. This allows you to pass any
  non-secret variables to the worker. This configuration is directly
  inserted into the user data script without encryption.
EOF
  default     = ""
}

variable "disable_container_credentials" {
  type        = bool
  description = <<EOF
  If true, the run container will not be able to access the instance profile
  credentials by talking to the EC2 metadata endpoint. This is done by setting
  the number of hops in IMDSv2 to 1. Since the Docker container goes through an
  extra NAT step, this still allows the launcher to talk to the endpoint, but
  prevents the container from doing so.
  EOF
  default     = true
}

variable "domain_name" {
  type        = string
  description = "Top-level domain name to use for pulling the launcher binary"
  default     = "spacelift.io"
}

variable "ec2_instance_type" {
  type        = string
  description = "EC2 instance type for the workers. If an arm64-based AMI is used, this must be an arm64-based instance type."
  default     = "t3.micro"
}

variable "enabled_metrics" {
  type        = list(string)
  description = "List of CloudWatch metrics enabled on the ASG"
  default = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]
}

variable "custom_iam_role_name" {
  description = "Name of an existing IAM to use. Used `when create_iam_role` = `false`"
  type        = string
  default     = ""
}

variable "create_iam_role" {
  description = "Determines whether an IAM role is created or to use an existing IAM role"
  type        = bool
  default     = true
}

variable "launch_template_version" {
  description = "Launch template version. Can be version number, `$Latest`, or `$Default`"
  type        = string
  default     = null
}

variable "launch_template_default_version" {
  description = "Default Version of the launch template"
  type        = string
  default     = null
}

variable "launch_template_update_default_version" {
  description = "Whether to update Default Version each update. Conflicts with `default_version`"
  type        = bool
  default     = null
}

variable "lifecycle_hook_timeout" {
  description = "Timeout for the lifecycle hook in seconds"
  type        = number
  default     = 300
}

variable "min_size" {
  type        = number
  description = "Minimum numbers of workers to spin up"
  default     = 0
}

variable "max_size" {
  type        = number
  description = "Maximum number of workers to spin up"
  default     = 10
}

variable "poweroff_delay" {
  type        = number
  description = "Number of seconds to wait before powering the EC2 instance off after the Spacelift launcher stopped"
  default     = 15
}

variable "secure_env_vars_kms_key_id" {
  type        = string
  description = "KMS key ID to use for encrypting the secure strings, default is the default KMS key"
  default     = null
}

variable "security_groups" {
  type        = list(string)
  description = "List of security groups to use"
}

variable "tag_specifications" {
  description = "Tag specifications to set on the launch template, which will apply to the instances at launch"
  type = list(object({
    resource_type = string
    tags          = optional(map(string), {})
  }))
  default = []
}

variable "volume_encryption" {
  type        = bool
  default     = false
  description = "Whether to encrypt the EBS volume"
}

variable "volume_encryption_kms_key_id" {
  description = "KMS key ID to use for encrypting the EBS volume"
  type        = string
  default     = null
}

variable "volume_size" {
  type        = number
  default     = 40
  description = "Size of instance EBS volume"
}

variable "volume_throughput" {
  type        = number
  default     = null
  description = "Throughput in MiB/sec for instance EBS volume"
}

variable "vpc_subnets" {
  type        = list(string)
  description = "List of VPC subnets to use"
}

variable "worker_pool_id" {
  type        = string
  description = "ID (ULID) of the the worker pool."
  validation {
    condition     = can(regex("^[0-9A-HJKMNP-TV-Z]+$", var.worker_pool_id))
    error_message = "The worker pool ID must be a valid ULID (eg 01HCC6QZ932J7WDF4FTVM9QMEP)."
  }
}

variable "base_name" {
  type        = string
  description = "Base name for resources. If unset, it defaults to `sp5ft-$${var.worker_pool_id}`."
  nullable    = true
  default     = null
}

variable "enable_monitoring" {
  description = "Enables/disables detailed monitoring"
  type        = bool
  default     = true
}

variable "instance_refresh" {
  description = "If this block is configured, start an Instance Refresh when this Auto Scaling Group is updated based on instance refresh configration."
  type        = any
  default     = null
}

variable "instance_market_options" {
  description = <<EOF
  The market (purchasing) option for the instance. Configuration block for setting 
  up an instance on Spot vs On-Demand markets in the launch template.

  Configuration:
  - market_type: (Required) Type of market for the instance. Valid values: "spot"
  - spot_options: (Optional) Block to configure the Spot request
    - max_price: (Optional) The maximum hourly price you're willing to pay for the instance. 
      If not specified, you will pay the current Spot price (recommended). AWS does not 
      recommend using this parameter as it can lead to increased interruptions. 
      The price will never exceed the On-Demand price. Format: "0.05" (string)
    - spot_instance_type: (Optional) The Spot instance request type. For Auto Scaling Groups, 
      use "one-time" as ASG handles requesting new instances. Valid values: 
      "one-time" (recommended for ASG) or "persistent"
    - instance_interruption_behavior: (Optional) Indicates Spot instance behavior when 
      interrupted. Valid values: "terminate" (default), "stop", or "hibernate". 
      For persistent requests, "stop" and "hibernate" are valid.
    - block_duration_minutes: (Optional, Deprecated) The required duration for Spot block 
      instances in minutes. Note: Spot blocks are deprecated by AWS.

  Example configuration for spot instances:
  {
    market_type = "spot"
    spot_options = {
      spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"
      # max_price omitted to use current Spot price (recommended)
    }
  }
  
  ⚠️ WARNING: Spot instances are NOT recommended for critical workloads as they can be 
  interrupted with only 2 minutes notice, potentially causing:
  - Incomplete or corrupted Terraform state
  - Failed deployments leaving infrastructure in inconsistent state
  - Loss of work-in-progress for long-running operations
  Use only for non-critical development, testing, or ephemeral workloads.
  
  Note: Auto Scaling Groups only support 'one-time' Spot instance requests with no duration.
  EOF
  type        = any
  default     = null
}

variable "iam_permissions_boundary" {
  type        = string
  default     = null
  description = "ARN of the policy that is used to set the permissions boundary for any IAM roles."
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "autoscaling_configuration" {
  description = <<EOF
  Configuration for the autoscaler Lambda function. If null, the autoscaler will not be deployed. Configuration options are:
  - version: (optional) Version of the autoscaler to deploy.
  - architecture: (optional) Instruction set architecture of the autoscaler to use. Can be amd64 or arm64.
  - schedule_expression: (optional) Autoscaler scheduling expression. Default: rate(1 minute).
  - max_create: (optional) The maximum number of instances the utility is allowed to create in a single run.
  - max_terminate: (optional) The maximum number of instances the utility is allowed to terminate in a single run.
  - timeout: (optional) Timeout (in seconds) for a single autoscaling run. The more instances you have, the higher this should be.
  - s3_package: (optional) Configuration to retrieve autoscaler lambda package from a specific S3 bucket.
    - bucket: (mandatory) S3 bucket name
    - key: (mandatory) S3 object key
    - object_version: (optional) S3 object version
  - scale_down_delay: (optional) The number of minutes a worker must be registered to spacelift before it is eligible for termination. Default: 0 minutes.
  EOF

  type = object({
    version             = optional(string)
    architecture        = optional(string)
    schedule_expression = optional(string)
    max_create          = optional(number)
    max_terminate       = optional(number)
    timeout             = optional(number)
    s3_package = optional(object({
      bucket         = string
      key            = string
      object_version = optional(string)
    }))
    scale_down_delay = optional(number)
  })
  default = null
}

variable "autoscaling_vpc_subnets" {
  description = "List of VPC subnets to use for the autoscaler Lambda function."
  type        = list(string)
  default     = null
}

variable "autoscaling_vpc_sg_ids" {
  description = "values of the security group to use for the autoscaler Lambda function."
  type        = list(string)
  default     = null
}

variable "autoscaling_tracing_mode" {
  description = "Tracing mode for the autoscaler Lambda function. Can be 'Active' or 'PassThrough'. Default: 'Active'."
  type        = string
  default     = "Active"
  validation {
    condition     = contains(["Active", "PassThrough"], var.autoscaling_tracing_mode)
    error_message = "The autoscaling_tracing_mode must be either 'Active' or 'PassThrough'."
  }
}

variable "selfhosted_configuration" {
  description = <<EOF
  Configuration for selfhosted launcher. Configuration options are:
  - s3_uri: (mandatory) If provided, the launcher binary will be downloaded from that URI. Mandatory for selfhosted. Format: s3://<bucket>/<key>. For example: s3://spacelift-binaries-123ab/spacelift-launcher
  - run_launcher_as_spacelift_user: (optional) Whether to run the launcher process as the spacelift user with UID 1983, or to run as root.
  - http_proxy_config: (optional) The value of the HTTP_PROXY environment variable to pass to the launcher, worker containers, and Docker daemon.
  - https_proxy_config: (optional) The value of the HTTPS_PROXY environment variable to pass to the launcher, worker containers, and Docker daemon.
  - no_proxy_config: (optional) The value of the NO_PROXY environment variable to pass to the launcher, worker containers, and Docker daemon.
  - ca_certificates: (optional) List of additional root CAs to install on the instance. Example: ["-----BEGIN CERTIFICATE-----abc123-----END CERTIFICATE-----"].
  - power_off_on_error: (optional) Indicates whether the instance should poweroff when the launcher process exits. This allows the machine to be automatically be replaced by the ASG after error conditions. If an instance is crashing during startup, it can be useful to temporarily set this to false to allow you to connect to the instance and investigate.
  EOF

  type = object({
    s3_uri                         = string
    run_launcher_as_spacelift_user = optional(bool)
    http_proxy_config              = optional(string)
    https_proxy_config             = optional(string)
    no_proxy_config                = optional(string)
    ca_certificates                = optional(list(string))
    power_off_on_error             = optional(bool)
  })
  default = {
    s3_uri                         = ""
    run_launcher_as_spacelift_user = true
    http_proxy_config              = ""
    https_proxy_config             = ""
    no_proxy_config                = ""
    ca_certificates                = []
    power_off_on_error             = true
  }
}

variable "spacelift_api_credentials" {
  description = <<EOF
  Spacelift API credentials. This is used to authenticate the autoscaler and lifecycle manager with Spacelift. The credentials are stored in AWS Secrets Manager and SSM.
  - api_key_id: (mandatory) The ID of the Spacelift API key to use by the launcher.
  - api_key_secret: (optional) The secret corresponding to the Spacelift API key to use by the launcher.
  - api_key_endpoint: (mandatory) The full URL of the Spacelift API endpoint to use by the launcher. Example: https://mycorp.app.spacelift.io
  EOF
  sensitive   = true
  type = object({
    api_key_id       = string
    api_key_secret   = optional(string)
    api_key_endpoint = string
  })
  default = null
}

variable "cloudwatch_log_group_retention" {
  description = "Retention period for the autoscaler and lifecycle manager cloudwatch log group."
  type        = number
  default     = 7
}

variable "extra_iam_statements" {
  description = "Extra IAM statements to add to the created IAM role. **All statements should have a SID.** Requires `create_iam_role` to be `true`."
  type        = list(string)
  default     = []
}
