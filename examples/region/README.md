# Worker pool in a region other than the provider's

In this example, the provider is configured for `eu-west-1`, but the worker pool is deployed into `us-east-1` by setting the `region` variable.

The VPC, subnet, and security group lookups use a second provider configured for `us-east-1`, because the worker pool must run in the same region as the subnets it's placed into.
