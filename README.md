# Terraform AWS Spacelift Workerpool On EC2

Terraform module deploying a Spacelift worker pool on AWS EC2 using an autoscaling group.

## Usage

The most important is that you should provide `SPACELIFT_TOKEN` and `SPACELIFT_POOL_PRIVATE_KEY` environmental variables in the `configuration` variable to the module. More information can be found in the [docs](https://docs.spacelift.io/concepts/worker-pools).

```terraform
terraform {
  required_providers {
    google = {
      source  = "hashicorp/aws"
      version = "~> 4.48.0"
    }
  }
}

module "my_workerpool" {
  source = "github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2?ref=v1.3.0"

  configuration = <<-EOT
    export SPACELIFT_TOKEN="${var.worker_pool_config}"
    export SPACELIFT_POOL_PRIVATE_KEY="${var.worker_pool_private_key}"
  EOT

  min_size          = 1
  max_size          = 5
  worker_pool_id    = var.worker_pool_id
  security_groups   = var.worker_pool_security_groups
  vpc_subnets       = var.worker_pool_subnets
}
```

## Default AMI

The default AMI used by this module comes from the [spacelift-worker-image](https://github.com/spacelift-io/spacelift-worker-image)
repository. You can find the full list of AMIs on the [releases](https://github.com/spacelift-io/spacelift-worker-image/releases)
page.

## ARM-based AMI

You can use an ARM-based AMI by setting the `ami_id` variable to an arm64 AMI, and `ec2_instance_type` to an ARM-based instance type (e.g. `t4g.micro`).

We recommend using [Spacelift AMIs](https://github.com/spacelift-io/spacelift-worker-image/releases) because they come with every required tool preinstalled.

You can find an example of ARM-based workerpool in the [examples](./examples/) directory.

>❗️ If you use [custom runner images](https://docs.spacelift.io/concepts/stack/stack-settings.html#runner-image), make sure they support ARM. The default Spacelift images do support it.

## How to generate docs

The generated documentation is between `BEGIN_TF_DOCS` and `END_TF_DOCS` comments in the `README.md` file.
Use the following command to update the docs:

```bash
$ make docs
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_asg"></a> [asg](#module\_asg) | terraform-aws-modules/autoscaling/aws | ~> 6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_ami.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_tags"></a> [additional\_tags](#input\_additional\_tags) | Additional tags to set on the resources | `map(string)` | `{}` | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | ID of the Spacelift AMI. If left empty, the latest Spacelift AMI will be used. | `string` | `""` | no |
| <a name="input_configuration"></a> [configuration](#input\_configuration) | User configuration. This allows you to decide how you want to pass your token<br>  and private key to the environment - be that directly, or using SSM Parameter<br>  Store, Vault etc. Ultimately, here you need to export SPACELIFT\_TOKEN and<br>  SPACELIFT\_POOL\_PRIVATE\_KEY to the environment. | `string` | n/a | yes |
| <a name="input_disable_container_credentials"></a> [disable\_container\_credentials](#input\_disable\_container\_credentials) | If true, the run container will not be able to access the instance profile<br>  credentials by talking to the EC2 metadata endpoint. This is done by setting<br>  the number of hops in IMDSv2 to 1. Since the Docker container goes through an<br>  extra NAT step, this still allows the launcher to talk to the endpoint, but<br>  prevents the container from doing so. | `bool` | `false` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Top-level domain name to use for pulling the launcher binary | `string` | `"spacelift.io"` | no |
| <a name="input_ec2_instance_type"></a> [ec2\_instance\_type](#input\_ec2\_instance\_type) | EC2 instance type for the workers. If an arm64-based AMI is used, this must be an arm64-based instance type. | `string` | `"t3.micro"` | no |
| <a name="input_enabled_metrics"></a> [enabled\_metrics](#input\_enabled\_metrics) | List of CloudWatch metrics enabled on the ASG | `list(string)` | <pre>[<br>  "GroupDesiredCapacity",<br>  "GroupInServiceInstances",<br>  "GroupMaxSize",<br>  "GroupMinSize",<br>  "GroupPendingInstances",<br>  "GroupStandbyInstances",<br>  "GroupTerminatingInstances",<br>  "GroupTotalInstances"<br>]</pre> | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum number of workers to spin up | `number` | `10` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum numbers of workers to spin up | `number` | `0` | no |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | List of security groups to use | `list(string)` | n/a | yes |
| <a name="input_volume_encryption"></a> [volume\_encryption](#input\_volume\_encryption) | Whether to encrypt the EBS volume | `bool` | `false` | no |
| <a name="input_volume_size"></a> [volume\_size](#input\_volume\_size) | Size of instance EBS volume | `number` | `40` | no |
| <a name="input_vpc_subnets"></a> [vpc\_subnets](#input\_vpc\_subnets) | List of VPC subnets to use | `list(string)` | n/a | yes |
| <a name="input_worker_pool_id"></a> [worker\_pool\_id](#input\_worker\_pool\_id) | ID of the the worker pool. It is used for the naming convention of the resources. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_autoscaling_group_arn"></a> [autoscaling\_group\_arn](#output\_autoscaling\_group\_arn) | ARN of the auto scaling group |
| <a name="output_instances_role_arn"></a> [instances\_role\_arn](#output\_instances\_role\_arn) | ARN of the IAM role of the EC2 instances |
| <a name="output_instances_role_name"></a> [instances\_role\_name](#output\_instances\_role\_name) | Name of the IAM role of the EC2 instances |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | ID of the launch template |
<!-- END_TF_DOCS -->
