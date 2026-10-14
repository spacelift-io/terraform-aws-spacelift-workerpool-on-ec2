# Worker pool in self-hosted Spacelift, launcher from the downloads CDN

This is an example of deploying a worker pool for self-hosted Spacelift that downloads the
launcher for your self-hosted version from `https://downloads.spacelift.io/self-hosted/<version>/`
instead of from your own S3 bucket.

On boot the instance picks the binary for its architecture (`x86_64` or `aarch64`), verifies the
GPG signature of its checksum file with the Spacelift self-hosted key from `keys.openpgp.org`, checks
the checksum, and only then runs it.

- `launcher_version` must match your self-hosted version. Bump it when you upgrade Spacelift and
  replace the instances.
- Set `launcher_fips = true` to use the FIPS 140 build.
- Instances need outbound HTTPS access to `downloads.spacelift.io` and `keys.openpgp.org`. If they
  can't have it, upload the launcher to your own bucket and use `s3_uri` instead (see the [self-hosted example](../self-hosted/)).
