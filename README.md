# ☁️ Terraform AWS Spacelift Workerpool On EC2

Terraform module deploying a Spacelift worker pool on AWS EC2 using an autoscaling group.

This module can optionally deploy [a Lambda function](https://github.com/spacelift-io/ec2-workerpool-autoscaler) to auto-scale the worker pool. The function adds or removes workers depending on the worker pool queue length.

> 🚨 **Breaking changes in v3.0.0** 🚨
> 
> See the [release notes](https://github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2/releases/tag/v3.0.0) for more information on the breaking changes in v3.0.0.

## ✨ Usage

More examples can be found in the [examples](./examples) directory.

### SaaS

The most important is that you should provide `SPACELIFT_TOKEN` and `SPACELIFT_POOL_PRIVATE_KEY` environmental variables in the `secure_env_vars` variable to the module. More information can be found in the [docs](https://docs.spacelift.io/concepts/worker-pools).

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
  region = "eu-west-1"
}

module "my_workerpool" {
  source = "github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2?ref=v3.0.4"
  
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
  security_groups   = var.worker_pool_security_groups
  vpc_subnets       = var.worker_pool_subnets
}
```

> ❗️ Previous versions of this module (`<v3`) placed the token and private key directly into the `configuration` variable. This is still supported for [non-sensitive configuration options](https://docs.spacelift.io/concepts/worker-pools.html#configuration-options), but for the worker pool token and private key, it is highly recommended to use the `secure_env_vars` variable as this will store the values in [Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html) instead of having it in plaintext in the userdata.

You can also set the optional `secure_env_vars_kms_key_id` to a KMS key id to use for encrypting the secure strings in Secrets Manager. This defaults to the default KMS key that AWS uses.

#### Autoscaling

You can enable autoscaling by setting the `autoscaling_configuration` variable. This will deploy a Lambda function (and a few surrounding resources) to autoscale the worker pool based on the queue length. The Lambda invokes the Spacelift API to collect information about the worker pool's current state and then scales the worker pool based on the queue length.

When providing an `autoscaling_configuration`, you can define the following parameters:

- `api_key_id` - (mandatory) ID of the Spacelift API key to be used by the [autoscaler Lambda function](https://github.com/spacelift-io/ec2-workerpool-autoscaler).
- `api_key_secret` - (mandatory) Secret corresponding to the Spacelift API key to be used by the autoscaler Lambda function.
- `api_key_endpoint` - (mandatory) Full URL of the Spacelift account, eg. `https://mycompany.app.spacelift.io`.
- `version` - (optional) Version of the autoscaler Lambda function to deploy. Defaults to `latest`.
- `architecture` - (optional) Instruction set architecture of the autoscaler Lambda function to use. Can be either `amd64` or `arm64` .Defaults to `amd64`.
- `schedule_expression` - (optional) Cron expression to fire off the autoscaler. Defaults to `rate(1 minute)`.
- `max_create` - (optional) The maximum number of instances the utility is allowed to create in a single run. Defaults to `1`.
- `max_terminate` - (optional) The maximum number of instances the utility is allowed to terminate in a single run. Defaults to `1`.
- `timeout` - (optional) Timeout (in seconds) for a single autoscaling run. The more instances you have, the higher this should be. Defaults to `30`.
- `s3_package` - (optional) Configuration to retrieve the autoscaler Lambda package from an S3 bucket. If not provided, the latest version of the autoscaler Lambda function will be used.

Example:

```hcl
module "my_workerpool" {
  source = "github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2?ref=v3.0.4"
  
  secure_env_vars = {
    SPACELIFT_TOKEN            = var.worker_pool_config
    SPACELIFT_POOL_PRIVATE_KEY = var.worker_pool_private_key
  }

  worker_pool_id    = var.worker_pool_id
  security_groups   = var.worker_pool_security_groups
  vpc_subnets       = var.worker_pool_subnets

  autoscaling_configuration = {
    api_key_id       = var.spacelift_api_key_id
    api_key_secret   = var.spacelift_api_key_secret
    api_key_endpoint = var.spacelift_api_key_endpoint
  }
}
```

### Self-hosted

For self-hosted, other than the aforementioned `SPACELIFT_TOKEN` and `SPACELIFT_POOL_PRIVATE_KEY` variables, you also need to provide the `selfhosted_configuration` variable. In `selfhosted_configuration`, the only mandatory field is `s3_uri` which should point to the location of the launcher binary in S3:

```terraform
module "my_workerpool" {
  source = "github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2?ref=v3.0.4"

  secure_env_vars = {
    SPACELIFT_TOKEN = var.worker_pool_config
    SPACELIFT_POOL_PRIVATE_KEY = var.worker_pool_private_key
  }

  min_size                 = 1
  max_size                 = 5
  worker_pool_id           = var.worker_pool_id
  security_groups          = var.worker_pool_security_groups
  vpc_subnets              = var.worker_pool_subnets
  selfhosted_configuration = {
    s3_uri = "s3://spacelift-binaries-123ab/spacelift-launcher"
  }
}
```

> Note: the module will parse the `s3_uri` and set `s3:GetObject` IAM permission accordingly. However, if the S3 bucket is KMS encrypted, it will fail. In that case, you can create a custom instance profile for yourself and provide it via the `custom_iam_role_name` variable.

## Default AMI

The default AMI used by this module comes from the [spacelift-worker-image](https://github.com/spacelift-io/spacelift-worker-image)
repository. You can find the full list of AMIs on the [releases](https://github.com/spacelift-io/spacelift-worker-image/releases)
page.

## ARM-based AMI

You can use an ARM-based AMI by setting the `ami_id` variable to an arm64 AMI, and `ec2_instance_type` to an ARM-based instance type (e.g. `t4g.micro`).

We recommend using [Spacelift AMIs](https://github.com/spacelift-io/spacelift-worker-image/releases) because they come with every required tool preinstalled.

You can find an example of ARM-based workerpool in the [examples](./examples/) directory.

>❗️ If you use [custom runner images](https://docs.spacelift.io/concepts/stack/stack-settings.html#runner-image), make sure they support ARM. The default Spacelift images do support it.

## Module registries

The module is also available [on the OpenTofu registry](https://search.opentofu.org/module/spacelift-io/spacelift-workerpool-on-ec2/aws/latest) where you can browse the input and output variables.
