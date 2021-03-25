# terraform-aws-spacelift-workerpool-on-ec2

Terraform module deploying a Spacelift worker pool on AWS EC2 using an autoscaling group.

## Usage

```terraform
module "my_workerpool" {
  source = "github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2?ref=71733248ac1a509ec408b89d31828a9cef15ce3f"

  configuration = <<-EOT
    export SPACELIFT_TOKEN="${var.worker_pool_config}"
    export SPACELIFT_POOL_PRIVATE_KEY="${var.worker_pool_private_key}"
  EOT

  max_size          = 1
  ami_id            = var.worker_pool_ami_id
  worker_pool_id    = var.worker_pool_id
  security_groups   = var.worker_pool_security_groups
  vpc_subnets       = var.worker_pool_subnets
}
```
