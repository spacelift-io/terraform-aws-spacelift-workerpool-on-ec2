# ☁️ Terraform AWS Spacelift Workerpool On EC2

Terraform module for deploying a Spacelift worker pool on AWS EC2 using an autoscaling group.

This module supports both SaaS and self-hosted Spacelift deployments, and can optionally deploy [a Lambda function](https://github.com/spacelift-io/ec2-workerpool-autoscaler) to auto-scale the worker pool based on queue length.

## 📋 Features

- Deploy Spacelift worker pools on EC2 instances with autoscaling
- Support for both SaaS and self-hosted Spacelift deployments
- Automatically uses the FedRAMP worker image for FedRAMP worker pools
- Optional autoscaling based on worker pool queue length
- Secure storage of credentials using AWS Secrets Manager
- Support for ARM64 instances for cost optimization
- Spot instance support for significant cost savings (up to 90%)
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
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

module "spacelift_workerpool" {
  source = "github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2?ref=v5.3.1"

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

### Other Examples

For more examples covering specific use cases, please see the [examples directory](./examples/):

- [AMD64 deployment](./examples/amd64/)
- [ARM64 deployment](./examples/arm64/)
- [Spot instances for cost optimization](./examples/spot-instances/)
- [Autoscaler configuration](./examples/autoscaler/)
- [Custom S3 package for autoscaler](./examples/autoscaler-custom-s3-package/)
- [BYO SSM and Secrets Manager](./examples/byo-ssm-secretsmanager-with-autoscaling-and-lifecycle/)
- [Extra IAM statements](./examples/extra-iam-statements/)
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

## 💰 Spot Instances for Cost Optimization

This module supports AWS Spot Instances, which can provide significant cost savings (up to 90%) compared to On-Demand instances. Spot instances use spare AWS capacity and are ideal for fault-tolerant and flexible workloads.

> ⚠️ Spot instances are **NOT recommended for critical workloads** as they can be interrupted with only 2 minutes notice, potentially causing:
> - Incomplete or corrupted Terraform state
> - Failed deployments leaving infrastructure in inconsistent state
> - Loss of work-in-progress for long-running operations

### How to Enable Spot Instances

Configure spot instances using the `instance_market_options` variable:

```hcl
module "spacelift_workerpool" {
  source = "github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2"

  # ... other configuration ...

  # Enable spot instances
  instance_market_options = {
    market_type = "spot"
    # spot_options = {
    #  spot_instance_type             = "one-time"
    #  instance_interruption_behavior = "terminate"
    # }
  }
}
```

### Configuration Options

- **max_price** (Optional): Maximum hourly price you're willing to pay. AWS recommends omitting this to use current Spot pricing, as setting a lower price can increase interruption frequency.
- **spot_instance_type**: Use `"one-time"` for Auto Scaling Groups (recommended) or `"persistent"` for individual instances.
- **instance_interruption_behavior**: How instances behave when interrupted - `"terminate"` (default), `"stop"`, or `"hibernate"`. For AutoScaling Groups, it's recommended to use `"terminate"`, as the ASG handles replacements automatically.

These options use sensible defaults when omitted, so explicit configuration is typically unnecessary.

Use the [AWS EC2 Spot Instance Advisor](https://aws.amazon.com/ec2/spot/instance-advisor/) to select cost-effective instance types and understand interruption rates.

### Graceful Spot Instance Interruption Handling

The Spacelift worker includes built-in spot instance interruption detection to minimize job disruption:

- **Automatic Monitoring**: The worker polls the EC2 Instance Metadata Service for spot interruption notices
- **Graceful Shutdown**: When an interruption is detected, the worker:
  - Exits immediately if idle (no active runs)
  - If processing a run, allows the current run to finish without cancellation, then shuts down gracefully
  - **Important**: If the run doesn't complete within the 2-minute interruption grace period, the run will be abruptly terminated and crash

**Reference**: [AWS Spot Instance Termination Notices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-instance-termination-notices.html)

For a complete example, see the [spot instances example](./examples/spot-instances/).

## Default AMI

The default AMI used by this module comes from the [spacelift-worker-image](https://github.com/spacelift-io/spacelift-worker-image) repository. You can find the full list of AMIs on the [releases](https://github.com/spacelift-io/spacelift-worker-image/releases) page.

## ARM-based AMI

You can use an ARM-based AMI by setting the `ami_architecture` to `arm64`, or the `ami_id` variable to an arm64 AMI, and `ec2_instance_type` to an ARM-based instance type (e.g. `t4g.micro`).

We recommend using [Spacelift AMIs](https://github.com/spacelift-io/spacelift-worker-image/releases) because they come with every required tool preinstalled.

Self hosted does not currently support ARM.

>❗️ If you use [custom runner images](https://docs.spacelift.io/concepts/stack/stack-settings.html#runner-image), make sure they support ARM. The default Spacelift images do support it.

## Module Registries

This module is also available [on the OpenTofu registry](https://search.opentofu.org/module/spacelift-io/spacelift-workerpool-on-ec2/aws/latest) where you can browse the input and output variables.
