# HTTP Long-Poll Worker Communication

This example deploys a SaaS worker pool using the module's default HTTP long-poll transport.

The module exports these values before starting the launcher:

```sh
SPACELIFT_WORKER_COMMS_PROTOCOL=poll
SPACELIFT_WORKER_COMMS_URL=https://app.spacelift.io
```

No communication-specific input is needed for the default EU SaaS environment. For US-region SaaS, set `domain_name = "us.spacelift.io"`. For self-hosted and FedRAMP Spacelift, set `worker_comms_url` to the base URL provided for the environment.

To temporarily retain the deprecated MQTT transport during migration, set:

```hcl
worker_comms_protocol = "mqtt"
```
