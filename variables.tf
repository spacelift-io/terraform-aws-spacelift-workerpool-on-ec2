variable "ami_id" {
  type        = string
  description = "ID of the Spacelift AMI. If left empty, the latest Spacelift AMI will be used."
  default     = ""
}

variable "configuration" {
  type        = string
  description = <<EOF
  User configuration. This allows you to decide how you want to pass your token
  and private key to the environment if you dont wish to use secrets manager and
  the secret strings functionality - be that directly, or using SSM Parameter
  Store, Vault etc.

  NOTE: One of var.configuration or var.secure_env_vars is required.
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

variable "secure_env_vars" {
  type        = map(string)
  description = <<EOF
    Secure env vars to be stored in Secrets Manager, their values will be exported
    at run time as `export {key}={value}`. This allows you pass the token, private
    key, or any values securely.

    NOTE: One of var.configuration or var.secure_env_vars is required.
EOF
  default     = {}
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

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags to set on the resources"
  default     = {}
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

variable "volume_size" {
  type        = number
  default     = 40
  description = "Size of instance EBS volume"
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
  default     = {}
}

variable "enable_autoscaling" {
  default     = true
  description = "Determines whether to create the Lambda Autoscaler function and dependent resources or not"
  type        = bool
}

variable "autoscaler_version" {
  description = "Version of the autoscaler to deploy"
  type        = string
  default     = "latest"
  nullable    = false
}

variable "autoscaler_architecture" {
  type        = string
  description = "Instruction set architecture of the autoscaler to use"
  default     = "amd64"
}

variable "spacelift_api_key_id" {
  type        = string
  description = "ID of the Spacelift API key to use"
  default     = null
}

variable "spacelift_api_key_secret" {
  type        = string
  sensitive   = true
  description = "Secret corresponding to the Spacelift API key to use"
  default     = null
}

variable "spacelift_api_key_endpoint" {
  type        = string
  description = "Full URL of the Spacelift API endpoint to use, eg. https://demo.app.spacelift.io"
  default     = null
}

variable "schedule_expression" {
  type        = string
  description = "Autoscaler scheduling expression"
  default     = "rate(1 minute)"
}

variable "volume_encryption_kms_key_id" {
  description = "KMS key ID to use for encrypting the EBS volume"
  type        = string
  default     = null
}

variable "autoscaling_max_create" {
  description = "The maximum number of instances the utility is allowed to create in a single run"
  type        = number
  default     = 1
}

variable "autoscaling_max_terminate" {
  description = "The maximum number of instances the utility is allowed to terminate in a single run"
  type        = number
  default     = 1
}

variable "autoscaling_timeout" {
  type        = number
  description = "Timeout (in seconds) for a single autoscaling run. The more instances you have, the higher this should be."
  default     = 30
}

variable "autoscaler_s3_package" {
  type = object({
    bucket         = string
    key            = string
    object_version = optional(string)
  })
  description = "Configuration to retrieve autoscaler lambda package from s3 bucket"
  default     = null
}

variable "instance_market_options" {
  description = "The market (purchasing) option for the instance"
  type        = any
  default     = {}
}

variable "permissions_boundary" {
  type        = string
  default     = null
  description = "ARN of the policy that is used to set the permissions boundary for any IAM roles."
}

variable "selfhosted_configuration" {
  type = object({
    s3_uri                         = string                 # If provided, the launcher binary will be downloaded from that URI. Mandatory for selfhosted. Format: s3://<bucket>/<key>. For example: s3://spacelift-binaries-123ab/spacelift-launcher
    run_launcher_as_spacelift_user = optional(bool)         # Whether to run the launcher process as the spacelift user with UID 1983, or to run as root.
    http_proxy_config              = optional(string)       # The value of the HTTP_PROXY environment variable to pass to the launcher, worker containers, and Docker daemon.
    https_proxy_config             = optional(string)       # The value of the HTTPS_PROXY environment variable to pass to the launcher, worker containers, and Docker daemon.
    no_proxy_config                = optional(string)       # The value of the NO_PROXY environment variable to pass to the launcher, worker containers, and Docker daemon.
    ca_certificates                = optional(list(string)) # List of additional root CAs to install on the instance. Example: [\"-----BEGIN CERTIFICATE-----abc123-----END CERTIFICATE-----\"].
    power_off_on_error             = optional(bool)         # Indicates whether the instance should poweroff when the launcher process exits. This allows the machine to be automatically be replaced by the ASG after error conditions. If an instance is crashing during startup, it can be useful to temporarily set this to false to allow you to connect to the instance and investigate.
  })
  description = "Configuration for selfhosted launcher"
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
