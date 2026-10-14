# Self-hosted launcher version and S3 URI (Negative Test)

This example is a **negative test**: it is expected to fail at plan time.

The self-hosted launcher comes either from your own bucket (`s3_uri`) or from the downloads CDN
(`launcher_version`). This example sets both, so the module's validation rejects the plan:

```
selfhosted_configuration.s3_uri and selfhosted_configuration.launcher_version cannot be used together.
```

It is registered in `.spacelift/config.yml` with `negative: true`, so the Spacelift module test
passes only when the plan fails. See the [launcher version example](../self-hosted-launcher-version/)
for the working configuration.

## Usage

```shell
terraform init
terraform plan   # expected to fail
```
