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
  source = "github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2?ref=v4.4.0"
  
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

You can use an ARM-based AMI by setting the `ami_architecture` to `arm64`, or the `ami_id` variable to an arm64 AMI, and `ec2_instance_type` to an ARM-based instance type (e.g. `t4g.micro`).

We recommend using [Spacelift AMIs](https://github.com/spacelift-io/spacelift-worker-image/releases) because they come with every required tool preinstalled.

Self hosted does not currently support ARM.

>❗️ If you use [custom runner images](https://docs.spacelift.io/concepts/stack/stack-settings.html#runner-image), make sure they support ARM. The default Spacelift images do support it.

## Module Registries

This module is also available [on the OpenTofu registry](https://search.opentofu.org/module/spacelift-io/spacelift-workerpool-on-ec2/aws/latest) where you can browse the input and output variables.

## 📝 Input Variables

### Required Variables

| Name | Description | Type | Definition |
|------|-------------|------|------------|
| `worker_pool_id` | ID (ULID) of the the worker pool. | `string` | [variables.tf:195-202](./variables.tf#L195-L202) |
| `security_groups` | List of security groups to use | `list(string)` | [variables.tf:158-161](./variables.tf#L158-L161) |
| `vpc_subnets` | List of VPC subnets to use | `list(string)` | [variables.tf:190-193](./variables.tf#L190-L193) |

### Optional Variables

| Name | Description | Type | Default | Definition |
|------|-------------|------|---------|------------|
| `secure_env_vars` | Secure env vars to be stored in Secrets Manager. See definition for full details. | `map(string)` | `{}` | [variables.tf:37-46](./variables.tf#L37-L46) |
| `configuration` | Plain text user configuration for non-secret variables. See definition for full details. | `string` | `""` | [variables.tf:49-57](./variables.tf#L49-L57) |
| `min_size` | Minimum numbers of workers to spin up | `number` | `0` | [variables.tf:134-138](./variables.tf#L134-L138) |
| `max_size` | Maximum number of workers to spin up | `number` | `10` | [variables.tf:140-144](./variables.tf#L140-L144) |
| `ami_id` | ID of the Spacelift AMI. If left empty, the latest Spacelift AMI will be used. | `string` | `""` | [variables.tf:1-5](./variables.tf#L1-L5) |
| `ec2_instance_type` | EC2 instance type for the workers. If an arm64-based AMI is used, this must be an arm64-based instance type. | `string` | `"t3.micro"` | [variables.tf:77-81](./variables.tf#L77-L81) |
| `volume_size` | Size of instance EBS volume | `number` | `40` | [variables.tf:184-188](./variables.tf#L184-L188) |
| `volume_encryption` | Whether to encrypt the EBS volume | `bool` | `false` | [variables.tf:172-176](./variables.tf#L172-L176) |
| `create_iam_role` | Determines whether an IAM role is created or to use an existing IAM role | `bool` | `true` | [variables.tf:104-108](./variables.tf#L104-L108) |
| `custom_iam_role_name` | Name of an existing IAM to use. Used `when create_iam_role` = `false` | `string` | `""` | [variables.tf:98-102](./variables.tf#L98-L102) |
| `base_name` | Base name for resources. If unset, it defaults to `sp5ft-${var.worker_pool_id}`. | `string` | `null` | [variables.tf:204-209](./variables.tf#L204-L209) |
| `additional_tags` | Additional tags to apply to all resources | `map(string)` | `{}` | [variables.tf:235-239](./variables.tf#L235-L239) |
| `enable_monitoring` | Enables/disables detailed monitoring | `bool` | `true` | [variables.tf:211-215](./variables.tf#L211-L215) |

### Autoscaling Configuration

| Name | Description | Type                          | Default | Definition |
|------|-------------|-------------------------------|---------|------------|
| `autoscaling_configuration` | Configuration for the autoscaler Lambda function. If null, the autoscaler will not be deployed. See definition for full details. | `object`<br/>(See definition) | `null` | [variables.tf:241-270](./variables.tf#L241-L270) |
| `spacelift_api_credentials` | Spacelift API credentials used to authenticate the autoscaler and lifecycle manager with Spacelift. See definition for full details. | `object`<br/>(See definition) | `null` | [variables.tf:304-318](./variables.tf#L304-L318) |
| `instance_refresh` | If this block is configured, start an Instance Refresh when this Auto Scaling Group is updated | `any`                         | `{}` | [variables.tf:217-221](./variables.tf#L217-L221) |
| `instance_market_options` | The market (purchasing) option for the instance | `any`                         | `{}` | [variables.tf:223-227](./variables.tf#L223-L227) |
| `autoscaling_vpc_sg_ids` | Security groups that should be assigned to autoscaling lambda | `null`                         | `[]` | [variables.tf:223-227](./variables.tf#L272-L276) |
| `autoscaling_vpc_subnets` | Subnets that should be assigned to autoscaling lambda | `null`                         | `[]` | [variables.tf:223-227](./variables.tf#L278-L82) |

### Self-hosted Configuration

| Name | Description | Type                          | Default | Definition |
|------|-------------|-------------------------------|---------|------------|
| `selfhosted_configuration` | Configuration for selfhosted launcher, including S3 URI, user permissions, proxy settings, and more. See definition for full details. | `object`<br/>(See definition) | See definition | [variables.tf:272-301](./variables.tf#L272-L301) |
| `domain_name` | Top-level domain name to use for pulling the launcher binary | `string`                      | `"spacelift.io"` | [variables.tf:71-75](./variables.tf#L71-L75) |

### Bring Your Own (BYO) Variables

| Name | Description | Type                          | Default | Definition |
|------|-------------|-------------------------------|---------|------------|
| `byo_ssm` | Name and ARN of the SSM parameter to use for the autoscaler. See definition for full details. | `object`<br/>(See definition) | `null` | [variables.tf:7-16](./variables.tf#L7-L16) |
| `byo_secretsmanager` | Name and ARN of the Secrets Manager secret to use for the autoscaler and keys to export. See definition for full details. | `object`<br/>(See definition) | `null` | [variables.tf:19-35](./variables.tf#L19-L35) |

### Advanced Configuration

| Name | Description | Type                                | Default | Definition |
|------|-------------|-------------------------------------|---------|------------|
| `enabled_metrics` | List of CloudWatch metrics enabled on the ASG | `list(string)`<br/>(See definition) | See definition | [variables.tf:83-95](./variables.tf#L83-L95) |
| `disable_container_credentials` | Controls whether containers can access EC2 instance profile credentials. See definition for full details. | `bool`                              | `true` | [variables.tf:59-69](./variables.tf#L59-L69) |
| `poweroff_delay` | Number of seconds to wait before powering the EC2 instance off after the Spacelift launcher stopped | `number`                            | `15` | [variables.tf:146-150](./variables.tf#L146-L150) |
| `secure_env_vars_kms_key_id` | KMS key ID to use for encrypting the secure strings, default is the default KMS key | `string`                            | `null` | [variables.tf:152-156](./variables.tf#L152-L156) |
| `volume_encryption_kms_key_id` | KMS key ID to use for encrypting the EBS volume | `string`                            | `null` | [variables.tf:178-182](./variables.tf#L178-L182) |
| `tag_specifications` | Tag specifications to set on the launch template, which will apply to the instances at launch | `list(object)`<br/>(See definition) | `[]` | [variables.tf:163-170](./variables.tf#L163-L170) |
| `launch_template_version` | Launch template version. Can be version number, `$Latest`, or `$Default` | `string`                            | `null` | [variables.tf:110-114](./variables.tf#L110-L114) |
| `launch_template_default_version` | Default Version of the launch template | `string`                            | `null` | [variables.tf:116-120](./variables.tf#L116-L120) |
| `launch_template_update_default_version` | Whether to update Default Version each update. Conflicts with `default_version` | `bool`                              | `null` | [variables.tf:122-126](./variables.tf#L122-L126) |
| `lifecycle_hook_timeout` | Timeout for the lifecycle hook in seconds | `number`                            | `300` | [variables.tf:128-132](./variables.tf#L128-L132) |
| `iam_permissions_boundary` | ARN of the policy that is used to set the permissions boundary for any IAM roles. | `string`                            | `null` | [variables.tf:229-233](./variables.tf#L229-L233) |
| `cloudwatch_log_group_retention` | Retention period for the autoscaler and lifecycle manager cloudwatch log group. | `number`                            | `7` | [variables.tf:320-324](./variables.tf#L320-L324) |

## 🔍 Outputs

| Name | Description |
|------|-------------|
| `instances_role_arn` | ARN of the IAM role of the EC2 instances |
| `instances_role_name` | Name of the IAM role of the EC2 instances |
| `autoscaling_group_arn` | ARN of the auto scaling group |
| `autoscaling_group_name` | Name of the auto scaling group |
| `launch_template_id` | ID of the launch template |
| `secretsmanager_secret_arn` | ARN of the secret in Secrets Manager |
