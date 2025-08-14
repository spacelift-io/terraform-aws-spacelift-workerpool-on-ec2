# Spot Instances Example

This example demonstrates how to configure the Spacelift worker pool to use EC2 spot instances for cost optimization.

> ⚠️ Spot instances are **NOT recommended for critical workloads** as they can be interrupted with only 2 minutes notice, potentially causing:
> - Incomplete or corrupted Terraform state
> - Failed deployments leaving infrastructure in inconsistent state
> - Loss of work-in-progress for long-running operations

## Spot Instance Configuration

The key configuration for spot instances is:

```hcl
instance_market_options = {
  market_type = "spot"
  spot_options = {
    max_price                      = "0.05"  # Maximum price per hour in USD
    spot_instance_type             = "one-time"
    instance_interruption_behavior = "terminate"
  }
}
```

### Configuration Options

- **max_price** (Optional): Maximum hourly price you're willing to pay. AWS recommends omitting this to use current Spot pricing, as setting a lower price can increase interruption frequency.
- **spot_instance_type**: Use `"one-time"` for Auto Scaling Groups (recommended) or `"persistent"` for individual instances.
- **instance_interruption_behavior**: How instances behave when interrupted - `"terminate"` (default), `"stop"`, or `"hibernate"`. For AutoScaling Groups, it's recommended to use `"terminate"`, as the ASG handles replacements automatically.

These options use sensible defaults when omitted, so **explicit configuration is typically unnecessary**.
