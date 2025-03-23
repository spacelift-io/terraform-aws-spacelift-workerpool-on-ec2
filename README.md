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
  source = "github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2?ref=v3.0.0"
  
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
  source = "github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2?ref=v3.0.0"
  
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
  source = "github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2?ref=v3.0.0"

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

## 📚 How to generate docs

The generated documentation is between `BEGIN_TF_DOCS` and `END_TF_DOCS` comments in the `README.md` file.
Use the following command to update the docs:

```bash
$ make docs
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.55.0 |
| <a name="requirement_validation"></a> [validation](#requirement\_validation) | >= 1.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.55.0 |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |
| <a name="provider_validation"></a> [validation](#provider\_validation) | >= 1.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_asg"></a> [asg](#module\_asg) | terraform-aws-modules/autoscaling/aws | ~> 8.0 |
| <a name="module_autoscaler"></a> [autoscaler](#module\_autoscaler) | ./autoscaler | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.secure_env_vars](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.secure_env_vars](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_secretsmanager_secret.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [null_resource.token_check](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [validation_warning.token_or_private_key_in_plaintext](https://registry.terraform.io/providers/tlkamp/validation/latest/docs/resources/warning) | resource |
| [aws_ami.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_iam_policy_document.secure_env_vars](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_tags"></a> [additional\_tags](#input\_additional\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | ID of the Spacelift AMI. If left empty, the latest Spacelift AMI will be used. | `string` | `""` | no |
| <a name="input_autoscaling_configuration"></a> [autoscaling\_configuration](#input\_autoscaling\_configuration) | Configuration for the autoscaler Lambda function. If null, the autoscaler will not be deployed. Configuration options are:<br/>  - api\_key\_id: (mandatory) The ID of the Spacelift API key to use by the Autoscaling Lambda function.<br/>  - api\_key\_secret: (mandatory) The secret corresponding to the Spacelift API key to use by the Autoscaling Lambda function.<br/>  - api\_key\_endpoint: (mandatory) The full URL of the Spacelift API endpoint to use by the Autoscaling Lambda function. Example: https://mycorp.app.spacelift.io<br/>  - version: (optional) Version of the autoscaler to deploy.<br/>  - architecture: (optional) Instruction set architecture of the autoscaler to use. Can be amd64 or arm64.<br/>  - schedule\_expression: (optional) Autoscaler scheduling expression. Default: rate(1 minute).<br/>  - max\_create: (optional) The maximum number of instances the utility is allowed to create in a single run.<br/>  - max\_terminate: (optional) The maximum number of instances the utility is allowed to terminate in a single run.<br/>  - timeout: (optional) Timeout (in seconds) for a single autoscaling run. The more instances you have, the higher this should be.<br/>  - s3\_package: (optional) Configuration to retrieve autoscaler lambda package from a specific S3 bucket.<br/>    - bucket: (mandatory) S3 bucket name<br/>    - key: (mandatory) S3 object key<br/>    - object\_version: (optional) S3 object version | <pre>object({<br/>    api_key_id          = string<br/>    api_key_secret      = string<br/>    api_key_endpoint    = string<br/>    version             = optional(string)<br/>    architecture        = optional(string)<br/>    schedule_expression = optional(string)<br/>    max_create          = optional(number)<br/>    max_terminate       = optional(number)<br/>    timeout             = optional(number)<br/>    s3_package = optional(object({<br/>      bucket         = string<br/>      key            = string<br/>      object_version = optional(string)<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_base_name"></a> [base\_name](#input\_base\_name) | Base name for resources. If unset, it defaults to `sp5ft-${var.worker_pool_id}`. | `string` | `null` | no |
| <a name="input_configuration"></a> [configuration](#input\_configuration) | Plain text user configuration. This allows you to pass any<br/>  non-secret variables to the worker. This configuration is directly<br/>  inserted into the user data script without encryption. | `string` | `""` | no |
| <a name="input_create_iam_role"></a> [create\_iam\_role](#input\_create\_iam\_role) | Determines whether an IAM role is created or to use an existing IAM role | `bool` | `true` | no |
| <a name="input_custom_iam_role_name"></a> [custom\_iam\_role\_name](#input\_custom\_iam\_role\_name) | Name of an existing IAM to use. Used `when create_iam_role` = `false` | `string` | `""` | no |
| <a name="input_disable_container_credentials"></a> [disable\_container\_credentials](#input\_disable\_container\_credentials) | If true, the run container will not be able to access the instance profile<br/>  credentials by talking to the EC2 metadata endpoint. This is done by setting<br/>  the number of hops in IMDSv2 to 1. Since the Docker container goes through an<br/>  extra NAT step, this still allows the launcher to talk to the endpoint, but<br/>  prevents the container from doing so. | `bool` | `true` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Top-level domain name to use for pulling the launcher binary | `string` | `"spacelift.io"` | no |
| <a name="input_ec2_instance_type"></a> [ec2\_instance\_type](#input\_ec2\_instance\_type) | EC2 instance type for the workers. If an arm64-based AMI is used, this must be an arm64-based instance type. | `string` | `"t3.micro"` | no |
| <a name="input_enable_monitoring"></a> [enable\_monitoring](#input\_enable\_monitoring) | Enables/disables detailed monitoring | `bool` | `true` | no |
| <a name="input_enabled_metrics"></a> [enabled\_metrics](#input\_enabled\_metrics) | List of CloudWatch metrics enabled on the ASG | `list(string)` | <pre>[<br/>  "GroupDesiredCapacity",<br/>  "GroupInServiceInstances",<br/>  "GroupMaxSize",<br/>  "GroupMinSize",<br/>  "GroupPendingInstances",<br/>  "GroupStandbyInstances",<br/>  "GroupTerminatingInstances",<br/>  "GroupTotalInstances"<br/>]</pre> | no |
| <a name="input_iam_permissions_boundary"></a> [iam\_permissions\_boundary](#input\_iam\_permissions\_boundary) | ARN of the policy that is used to set the permissions boundary for any IAM roles. | `string` | `null` | no |
| <a name="input_instance_market_options"></a> [instance\_market\_options](#input\_instance\_market\_options) | The market (purchasing) option for the instance | `any` | `{}` | no |
| <a name="input_instance_refresh"></a> [instance\_refresh](#input\_instance\_refresh) | If this block is configured, start an Instance Refresh when this Auto Scaling Group is updated based on instance refresh configration. | `any` | `{}` | no |
| <a name="input_launch_template_default_version"></a> [launch\_template\_default\_version](#input\_launch\_template\_default\_version) | Default Version of the launch template | `string` | `null` | no |
| <a name="input_launch_template_update_default_version"></a> [launch\_template\_update\_default\_version](#input\_launch\_template\_update\_default\_version) | Whether to update Default Version each update. Conflicts with `default_version` | `bool` | `null` | no |
| <a name="input_launch_template_version"></a> [launch\_template\_version](#input\_launch\_template\_version) | Launch template version. Can be version number, `$Latest`, or `$Default` | `string` | `null` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum number of workers to spin up | `number` | `10` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum numbers of workers to spin up | `number` | `0` | no |
| <a name="input_poweroff_delay"></a> [poweroff\_delay](#input\_poweroff\_delay) | Number of seconds to wait before powering the EC2 instance off after the Spacelift launcher stopped | `number` | `15` | no |
| <a name="input_secure_env_vars"></a> [secure\_env\_vars](#input\_secure\_env\_vars) | Secure env vars to be stored in Secrets Manager. Their values will be exported<br/>    at run time as `export {key}={value}`. This allows you pass the token, private<br/>    key, or any values securely. | `map(string)` | n/a | yes |
| <a name="input_secure_env_vars_kms_key_id"></a> [secure\_env\_vars\_kms\_key\_id](#input\_secure\_env\_vars\_kms\_key\_id) | KMS key ID to use for encrypting the secure strings, default is the default KMS key | `string` | `null` | no |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | List of security groups to use | `list(string)` | n/a | yes |
| <a name="input_selfhosted_configuration"></a> [selfhosted\_configuration](#input\_selfhosted\_configuration) | Configuration for selfhosted launcher. Configuration options are:<br/>  - s3\_uri: (mandatory) If provided, the launcher binary will be downloaded from that URI. Mandatory for selfhosted. Format: s3://<bucket>/<key>. For example: s3://spacelift-binaries-123ab/spacelift-launcher<br/>  - run\_launcher\_as\_spacelift\_user: (optional) Whether to run the launcher process as the spacelift user with UID 1983, or to run as root.<br/>  - http\_proxy\_config: (optional) The value of the HTTP\_PROXY environment variable to pass to the launcher, worker containers, and Docker daemon.<br/>  - https\_proxy\_config: (optional) The value of the HTTPS\_PROXY environment variable to pass to the launcher, worker containers, and Docker daemon.<br/>  - no\_proxy\_config: (optional) The value of the NO\_PROXY environment variable to pass to the launcher, worker containers, and Docker daemon.<br/>  - ca\_certificates: (optional) List of additional root CAs to install on the instance. Example: ["-----BEGIN CERTIFICATE-----abc123-----END CERTIFICATE-----"].<br/>  - power\_off\_on\_error: (optional) Indicates whether the instance should poweroff when the launcher process exits. This allows the machine to be automatically be replaced by the ASG after error conditions. If an instance is crashing during startup, it can be useful to temporarily set this to false to allow you to connect to the instance and investigate. | <pre>object({<br/>    s3_uri                         = string<br/>    run_launcher_as_spacelift_user = optional(bool)<br/>    http_proxy_config              = optional(string)<br/>    https_proxy_config             = optional(string)<br/>    no_proxy_config                = optional(string)<br/>    ca_certificates                = optional(list(string))<br/>    power_off_on_error             = optional(bool)<br/>  })</pre> | <pre>{<br/>  "ca_certificates": [],<br/>  "http_proxy_config": "",<br/>  "https_proxy_config": "",<br/>  "no_proxy_config": "",<br/>  "power_off_on_error": true,<br/>  "run_launcher_as_spacelift_user": true,<br/>  "s3_uri": ""<br/>}</pre> | no |
| <a name="input_tag_specifications"></a> [tag\_specifications](#input\_tag\_specifications) | Tag specifications to set on the launch template, which will apply to the instances at launch | <pre>list(object({<br/>    resource_type = string<br/>    tags          = optional(map(string), {})<br/>  }))</pre> | `[]` | no |
| <a name="input_volume_encryption"></a> [volume\_encryption](#input\_volume\_encryption) | Whether to encrypt the EBS volume | `bool` | `false` | no |
| <a name="input_volume_encryption_kms_key_id"></a> [volume\_encryption\_kms\_key\_id](#input\_volume\_encryption\_kms\_key\_id) | KMS key ID to use for encrypting the EBS volume | `string` | `null` | no |
| <a name="input_volume_size"></a> [volume\_size](#input\_volume\_size) | Size of instance EBS volume | `number` | `40` | no |
| <a name="input_vpc_subnets"></a> [vpc\_subnets](#input\_vpc\_subnets) | List of VPC subnets to use | `list(string)` | n/a | yes |
| <a name="input_worker_pool_id"></a> [worker\_pool\_id](#input\_worker\_pool\_id) | ID (ULID) of the the worker pool. | `string` | n/a | yes |

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
