variable "ami_id" {
  type        = string
  description = "ID of the Spacelift AMI"
  default     = "ami-09c3c03b344b3e2c2"
}

variable "configuration" {
  type        = string
  description = <<EOF
  User configuration. This allows you to decide how you want to pass your token
  and private key to the environment - be that directly, or using SSM Parameter
  Store, Vault etc. Ultimately, here you need to export SPACELIFT_TOKEN and
  SPACELIFT_POOL_PRIVATE_KEY to the environment.
  EOF
}

variable "domain_name" {
  type        = string
  description = "Top-level domain name to use for pulling the launcher binary"
  default     = "spacelift.io"
}

variable "ec2_instance_type" {
  type        = string
  description = "EC2 instance type for the workers"
  default     = "t3.micro"
}

variable "max_size" {
  type        = number
  description = "Maximum number of workers to spin up"
  default     = 10
}

variable "security_groups" {
  type        = list(string)
  description = "List of security groups to use"
}

variable "tags" {
  type        = list
  description = "List of tags to set on the resources"
  default     = []
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
  description = "ID of the the worker pool"
}

locals {
  namespace = "sp5ft-${var.worker_pool_id}"
}
