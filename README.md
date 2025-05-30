<!-- BEGIN_TF_DOCS -->
# ☁️ Terraform AWS Spacelift Workerpool On EC2

Terraform module for deploying a Spacelift worker pool on AWS EC2 using an autoscaling group.

This module supports both SaaS and self-hosted Spacelift deployments, and can optionally deploy [a Lambda function](https://github.com/spacelift-io/ec2-workerpool-autoscaler) to auto-scale the worker pool based on queue length.

## 📋 Features

- Deploy Spacelift worker pools on EC2 instances with autoscaling
- Support for both SaaS and self-hosted Spacelift deployments
- Optional autoscaling based on worker pool queue length
- Secure storage of credentials using AWS Secrets Manager
- Support for ARM64 instances for cost optimization
- Instance lifecycle management with worker draining
- Configurable instance types, volume sizes, and more
- "Bring Your Own" (BYO) options for SSM parameters and Secrets Manager

## 🛠️ Usage

### Generic Example

Here's a basic example of how to use this module:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

module "spacelift_workerpool" {
  source = "github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2?ref=v4.2.0"

  secure_env_vars = {
    SPACELIFT_TOKEN            = var.worker_pool_config
    SPACELIFT_POOL_PRIVATE_KEY = var.worker_pool_private_key
  }

  configuration = <<EOF
    export SPACELIFT_SENSITIVE_OUTPUT_UPLOAD_ENABLED=true
  EOF

  min_size          = 1
  max_size          = 5
  worker_pool_id    = var.worker_pool_id
  security_groups   = var.security_groups
  vpc_subnets       = var.subnets
}
```

For more examples covering specific use cases, please see the [examples directory](./examples/):

- [AMD64 deployment](./examples/amd64/)
- [ARM64 deployment](./examples/arm64/)
- [Autoscaler configuration](./examples/autoscaler/)
- [Custom S3 package for autoscaler](./examples/autoscaler-custom-s3-package/)
- [BYO SSM and Secrets Manager](./examples/byo-ssm-secretsmanager-with-autoscaling-and-lifecycle/)
- [Custom IAM role](./examples/custom-iam-role/)
- [Self-hosted deployment](./examples/self-hosted/)

## 🔑 Credentials Management

### Using `secure_env_vars` (Recommended)

The recommended approach for managing sensitive worker pool credentials is to use the `secure_env_vars` variable:

```hcl
secure_env_vars = {
  SPACELIFT_TOKEN            = var.worker_pool_config
  SPACELIFT_POOL_PRIVATE_KEY = var.worker_pool_private_key
}
```

When you provide credentials via `secure_env_vars`:
- The module creates AWS Secrets Manager resources to securely store these values
- Values are encrypted at rest and only accessed by the worker instances at runtime
- The credentials are exported as environment variables in the worker's environment

> ❗️ Previous versions of this module (`<v3`) placed the token and private key directly into the `configuration` variable. This is still supported for [non-sensitive configuration options](https://docs.spacelift.io/concepts/worker-pools.html#configuration-options), but for the worker pool token and private key, it is highly recommended to use the `secure_env_vars` variable.

### Using "Bring Your Own" (BYO) Variables

Alternatively, you can use the BYO variables to provide your own pre-created AWS Secrets Manager and SSM resources:

```hcl
byo_secretsmanager = {
  name = aws_secretsmanager_secret.my_secret.name
  arn  = aws_secretsmanager_secret.my_secret.arn
  keys = [
    "SPACELIFT_TOKEN",
    "SPACELIFT_POOL_PRIVATE_KEY"
  ]
}

byo_ssm = {
  name = aws_ssm_parameter.api_key.name
  arn  = aws_ssm_parameter.api_key.arn
}
```

#### Important: Mutual Exclusivity

> ⚠️ **Important:** When using `byo_secretsmanager`, you should not use `secure_env_vars` for the same environment variables. These approaches are mutually exclusive for any given variable.
>
> - Use `secure_env_vars` when you want the module to manage your Secrets Manager resources
> - Use `byo_secretsmanager` when you have pre-existing Secrets Manager resources or need more control
> - If you use both, `byo_secretsmanager` takes precedence for the keys specified in its `keys` list

Similarly, when using `byo_ssm` for the autoscaler API credentials, you should not provide `api_key_secret` in the `spacelift_api_credentials` object, as these are mutually exclusive ways to provide the same information:

```hcl
# Either use this:
byo_ssm = {
  name = aws_ssm_parameter.api_key.name
  arn  = aws_ssm_parameter.api_key.arn
}

# Or use this:
spacelift_api_credentials = {
  api_key_endpoint = var.spacelift_api_key_endpoint
  api_key_id       = var.spacelift_api_key_id
  api_key_secret   = var.spacelift_api_key_secret  # This conflicts with byo_ssm
}

# But not both for the same credentials
```

## 🔄 Autoscaling

This module can optionally deploy a Lambda function that automatically scales the worker pool based on the number of pending jobs in the Spacelift queue.

### How It Works

1. The autoscaler periodically analyzes:
   - Number of schedulable runs waiting in the Spacelift queue
   - Number of idle worker instances
   - Current EC2 instance count
   - Auto-scaling group constraints (min/max size)

2. Scaling behavior:
   - When more schedulable runs than idle workers exist, it scales up the ASG
   - When more idle workers than schedulable runs exist, it safely scales down:
     - Drains workers before termination
     - Verifies workers are not busy
     - Prioritizes terminating oldest instances first

3. Configuration options:
   - Polling interval (how often the autoscaler checks the queue)
   - Scale-in and scale-out cooldown periods
   - Maximum instances to add/remove per scaling event
   - Minimum number of idle workers to maintain

To enable autoscaling, provide the `autoscaling_configuration` and `spacelift_api_credentials` variables. See the [autoscaler example](./examples/autoscaler/) for a complete configuration.

## 🔄 Instance Lifecycle Management

This module includes a lifecycle management feature that ensures graceful termination of worker instances during instance refresh operations.

### How It Works

1. When an instance is scheduled for replacement during an instance refresh:
   - The ASG lifecycle hook pauses the termination process
   - A message is sent to an SQS queue
   - The lifecycle manager Lambda function processes the message

2. The lifecycle manager:
   - Identifies the specific worker in the pool based on instance ID
   - Makes API calls to Spacelift to set the worker to "drain" mode
   - Waits for the worker to complete any running jobs
   - Once the worker is idle, completes the lifecycle hook to allow termination

3. Benefits:
   - Prevents interruption of running jobs during instance refresh events
   - Ensures smooth worker replacement with zero job interruption
   - Works specifically for instance refresh operations, not regular scale-in events (which are handled by the autoscaler)

To enable lifecycle management, provide the `spacelift_api_credentials` variable and configure the `instance_refresh` variable. See the [BYO SSM and Secrets Manager with Autoscaling and Lifecycle example](./examples/byo-ssm-secretsmanager-with-autoscaling-and-lifecycle/) for a complete configuration.

## Default AMI

The default AMI used by this module comes from the [spacelift-worker-image](https://github.com/spacelift-io/spacelift-worker-image) repository. You can find the full list of AMIs on the [releases](https://github.com/spacelift-io/spacelift-worker-image/releases) page.

## ARM-based AMI

You can use an ARM-based AMI by setting the `ami_id` variable to an arm64 AMI, and `ec2_instance_type` to an ARM-based instance type (e.g. `t4g.micro`).

We recommend using [Spacelift AMIs](https://github.com/spacelift-io/spacelift-worker-image/releases) because they come with every required tool preinstalled.

Self hosted does not currently support ARM.

>❗️ If you use [custom runner images](https://docs.spacelift.io/concepts/stack/stack-settings.html#runner-image), make sure they support ARM. The default Spacelift images do support it.

## Module Registries

This module is also available [on the OpenTofu registry](https://search.opentofu.org/module/spacelift-io/spacelift-workerpool-on-ec2/aws/latest) where you can browse the input and output variables.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| <a name="input_additional_tags"></a> [additional\_tags](#input\_additional\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | ID of the Spacelift AMI. If left empty, the latest Spacelift AMI will be used. | `string` | `""` |
| <a name="input_autoscaling_configuration"></a> [autoscaling\_configuration](#input\_autoscaling\_configuration) | Configuration for the autoscaler Lambda function. If null, the autoscaler will not be deployed. Configuration options are:<br/><br/>- version: Version of the autoscaler to deploy.<br/>- architecture: Instruction set architecture of the autoscaler to use. Can be amd64 or arm64.<br/>- schedule\_expression: Autoscaler scheduling expression. Default: rate(1 minute).<br/>- max\_create: The maximum number of instances the utility is allowed to create in a single run.<br/>- max\_terminate: The maximum number of instances the utility is allowed to terminate in a single run.<br/>- timeout: Timeout (in seconds) for a single autoscaling run. The more instances you have, the higher this should be.<br/>- s3\_package: Configuration to retrieve autoscaler lambda package from a specific S3 bucket.<br/>  - bucket: S3 bucket name<br/>  - key: S3 object key<br/>  - object\_version: S3 object version | <pre>object({<br/>    version             = optional(string)<br/>    architecture        = optional(string)<br/>    schedule_expression = optional(string)<br/>    max_create          = optional(number)<br/>    max_terminate       = optional(number)<br/>    timeout             = optional(number)<br/>    s3_package = optional(object({<br/>      bucket         = string<br/>      key            = string<br/>      object_version = optional(string)<br/>    }))<br/>  })</pre> | `null` |
| <a name="input_autoscaling_vpc_sg_ids"></a> [autoscaling\_vpc\_sg\_ids](#input\_autoscaling\_vpc\_sg\_ids) | values of the security group to use for the autoscaler Lambda function. | `list(string)` | `null` |
| <a name="input_autoscaling_vpc_subnets"></a> [autoscaling\_vpc\_subnets](#input\_autoscaling\_vpc\_subnets) | List of VPC subnets to use for the autoscaler Lambda function. | `list(string)` | `null` |
| <a name="input_base_name"></a> [base\_name](#input\_base\_name) | Base name for resources. If unset, it defaults to `sp5ft-${var.worker_pool_id}`. | `string` | `null` |
| <a name="input_byo_secretsmanager"></a> [byo\_secretsmanager](#input\_byo\_secretsmanager) | Name and ARN of the Secrets Manager secret to use for the autoscaler and keys to export. If left empty, the secret will be created for you.<br/>The keys will be exported as environment variables in the format `export {key}=$(echo $SECRET_VALUE \| jq -r '.{key}')`.<br/>The secret value must be a JSON object with the keys specified in the list. For example, if the list is ["key\_1", "key\_2"], the secret value must be:<pre>{<br/>  "key_1": "value_1",<br/>  "key_2": "value_2"<br/>}</pre> | <pre>object({<br/>    name = string<br/>    arn  = string<br/>    keys = list(string)<br/>  })</pre> | `null` |
| <a name="input_byo_ssm"></a> [byo\_ssm](#input\_byo\_ssm) | Name and ARN of the SSM parameter to use for the autoscaler. If left empty, the parameter will be created for you.<br/>  The parameter should only contain the Spacelift API key secret in plain text. | <pre>object({<br/>    name = string<br/>    arn  = string<br/>  })</pre> | `null` |
| <a name="input_cloudwatch_log_group_retention"></a> [cloudwatch\_log\_group\_retention](#input\_cloudwatch\_log\_group\_retention) | Retention period for the autoscaler and lifecycle manager cloudwatch log group. | `number` | `7` |
| <a name="input_configuration"></a> [configuration](#input\_configuration) | Plain text user configuration. This allows you to pass any<br/>  non-secret variables to the worker. This configuration is directly<br/>  inserted into the user data script without encryption. | `string` | `""` |
| <a name="input_create_iam_role"></a> [create\_iam\_role](#input\_create\_iam\_role) | Determines whether an IAM role is created or to use an existing IAM role | `bool` | `true` |
| <a name="input_custom_iam_role_name"></a> [custom\_iam\_role\_name](#input\_custom\_iam\_role\_name) | Name of an existing IAM to use. Used `when create_iam_role` = `false` | `string` | `""` |
| <a name="input_disable_container_credentials"></a> [disable\_container\_credentials](#input\_disable\_container\_credentials) | If true, the run container will not be able to access the instance profile<br/>  credentials by talking to the EC2 metadata endpoint. This is done by setting<br/>  the number of hops in IMDSv2 to 1. Since the Docker container goes through an<br/>  extra NAT step, this still allows the launcher to talk to the endpoint, but<br/>  prevents the container from doing so. | `bool` | `true` |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Top-level domain name to use for pulling the launcher binary | `string` | `"spacelift.io"` |
| <a name="input_ec2_instance_type"></a> [ec2\_instance\_type](#input\_ec2\_instance\_type) | EC2 instance type for the workers. If an arm64-based AMI is used, this must be an arm64-based instance type. | `string` | `"t3.micro"` |
| <a name="input_enable_monitoring"></a> [enable\_monitoring](#input\_enable\_monitoring) | Enables/disables detailed monitoring | `bool` | `true` |
| <a name="input_enabled_metrics"></a> [enabled\_metrics](#input\_enabled\_metrics) | List of CloudWatch metrics enabled on the ASG | `list(string)` | <pre>[<br/>  "GroupDesiredCapacity",<br/>  "GroupInServiceInstances",<br/>  "GroupMaxSize",<br/>  "GroupMinSize",<br/>  "GroupPendingInstances",<br/>  "GroupStandbyInstances",<br/>  "GroupTerminatingInstances",<br/>  "GroupTotalInstances"<br/>]</pre> |
| <a name="input_iam_permissions_boundary"></a> [iam\_permissions\_boundary](#input\_iam\_permissions\_boundary) | ARN of the policy that is used to set the permissions boundary for any IAM roles. | `string` | `null` |
| <a name="input_instance_market_options"></a> [instance\_market\_options](#input\_instance\_market\_options) | The market (purchasing) option for the instance | `any` | `{}` |
| <a name="input_instance_refresh"></a> [instance\_refresh](#input\_instance\_refresh) | If this block is configured, start an Instance Refresh when this Auto Scaling Group is updated based on instance refresh configration. | `any` | `{}` |
| <a name="input_launch_template_default_version"></a> [launch\_template\_default\_version](#input\_launch\_template\_default\_version) | Default Version of the launch template | `string` | `null` |
| <a name="input_launch_template_update_default_version"></a> [launch\_template\_update\_default\_version](#input\_launch\_template\_update\_default\_version) | Whether to update Default Version each update. Conflicts with `default_version` | `bool` | `null` |
| <a name="input_launch_template_version"></a> [launch\_template\_version](#input\_launch\_template\_version) | Launch template version. Can be version number, `$Latest`, or `$Default` | `string` | `null` |
| <a name="input_lifecycle_hook_timeout"></a> [lifecycle\_hook\_timeout](#input\_lifecycle\_hook\_timeout) | Timeout for the lifecycle hook in seconds | `number` | `300` |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum number of workers to spin up | `number` | `10` |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum numbers of workers to spin up | `number` | `0` |
| <a name="input_poweroff_delay"></a> [poweroff\_delay](#input\_poweroff\_delay) | Number of seconds to wait before powering the EC2 instance off after the Spacelift launcher stopped | `number` | `15` |
| <a name="input_secure_env_vars"></a> [secure\_env\_vars](#input\_secure\_env\_vars) | Secure env vars to be stored in Secrets Manager. Their values will be exported<br/>    at run time as `export {key}={value}`. This allows you pass the token, private<br/>    key, or any values securely. | `map(string)` | `{}` |
| <a name="input_secure_env_vars_kms_key_id"></a> [secure\_env\_vars\_kms\_key\_id](#input\_secure\_env\_vars\_kms\_key\_id) | KMS key ID to use for encrypting the secure strings, default is the default KMS key | `string` | `null` |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | List of security groups to use | `list(string)` | n/a |
| <a name="input_selfhosted_configuration"></a> [selfhosted\_configuration](#input\_selfhosted\_configuration) | Configuration for selfhosted launcher. Configuration options are:<br/>  - s3\_uri: URI to download launcher binary from.<br/>  - run\_launcher\_as\_spacelift\_user: Whether to run the launcher process as the spacelift user with UID 1983, or to run as root.<br/>  - http\_proxy\_config: The value of the HTTP\_PROXY environment variable to pass to the launcher, worker containers, and Docker daemon.<br/>  - https\_proxy\_config: The value of the HTTPS\_PROXY environment variable to pass to the launcher, worker containers, and Docker daemon.<br/>  - no\_proxy\_config: The value of the NO\_PROXY environment variable to pass to the launcher, worker containers, and Docker daemon.<br/>  - ca\_certificates: List of additional root CAs to install on the instance. Example: ["-----BEGIN CERTIFICATE-----abc123-----END CERTIFICATE-----"].<br/>  - power\_off\_on\_error: Indicates whether the instance should poweroff when the launcher process exits. This allows the machine to be automatically be replaced by the ASG after error conditions. If an instance is crashing during startup, it can be useful to temporarily set this to false to allow you to connect to the instance and investigate. | <pre>object({<br/>    s3_uri                         = string<br/>    run_launcher_as_spacelift_user = optional(bool)<br/>    http_proxy_config              = optional(string)<br/>    https_proxy_config             = optional(string)<br/>    no_proxy_config                = optional(string)<br/>    ca_certificates                = optional(list(string))<br/>    power_off_on_error             = optional(bool)<br/>  })</pre> | <pre>{<br/>  "ca_certificates": [],<br/>  "http_proxy_config": "",<br/>  "https_proxy_config": "",<br/>  "no_proxy_config": "",<br/>  "power_off_on_error": true,<br/>  "run_launcher_as_spacelift_user": true,<br/>  "s3_uri": ""<br/>}</pre> |
| <a name="input_spacelift_api_credentials"></a> [spacelift\_api\_credentials](#input\_spacelift\_api\_credentials) | Spacelift API credentials. This is used to authenticate the autoscaler and lifecycle manager with Spacelift. The credentials are stored in AWS Secrets Manager and SSM.<br/>  - api\_key\_id: The ID of the Spacelift API key to use by the launcher.<br/>  - api\_key\_secret: The secret corresponding to the Spacelift API key to use by the launcher.<br/>  - api\_key\_endpoint: The full URL of the Spacelift API endpoint to use by the launcher. Example: https://mycorp.app.spacelift.io | <pre>object({<br/>    api_key_id       = string<br/>    api_key_secret   = optional(string)<br/>    api_key_endpoint = string<br/>  })</pre> | `null` |
| <a name="input_tag_specifications"></a> [tag\_specifications](#input\_tag\_specifications) | Tag specifications to set on the launch template, which will apply to the instances at launch | <pre>list(object({<br/>    resource_type = string<br/>    tags          = optional(map(string), {})<br/>  }))</pre> | `[]` |
| <a name="input_volume_encryption"></a> [volume\_encryption](#input\_volume\_encryption) | Whether to encrypt the EBS volume | `bool` | `false` |
| <a name="input_volume_encryption_kms_key_id"></a> [volume\_encryption\_kms\_key\_id](#input\_volume\_encryption\_kms\_key\_id) | KMS key ID to use for encrypting the EBS volume | `string` | `null` |
| <a name="input_volume_size"></a> [volume\_size](#input\_volume\_size) | Size of instance EBS volume | `number` | `40` |
| <a name="input_vpc_subnets"></a> [vpc\_subnets](#input\_vpc\_subnets) | List of VPC subnets to use | `list(string)` | n/a |
| <a name="input_worker_pool_id"></a> [worker\_pool\_id](#input\_worker\_pool\_id) | ID (ULID) of the the worker pool. | `string` | n/a |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_autoscaling_group_arn"></a> [autoscaling\_group\_arn](#output\_autoscaling\_group\_arn) | ARN of the auto scaling group |
| <a name="output_autoscaling_group_name"></a> [autoscaling\_group\_name](#output\_autoscaling\_group\_name) | Name of the auto scaling group |
| <a name="output_instances_role_arn"></a> [instances\_role\_arn](#output\_instances\_role\_arn) | ARN of the IAM role of the EC2 instances. Will only be populated if the IAM role is created by this module |
| <a name="output_instances_role_name"></a> [instances\_role\_name](#output\_instances\_role\_name) | Name of the IAM role of the EC2 instances. Will only be populated if the IAM role is created by this module |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | ID of the launch template |
| <a name="output_secretsmanager_secret_arn"></a> [secretsmanager\_secret\_arn](#output\_secretsmanager\_secret\_arn) | ARN of the secret in Secrets Manager that holds the encrypted environment variables. |
<!-- END_TF_DOCS -->
