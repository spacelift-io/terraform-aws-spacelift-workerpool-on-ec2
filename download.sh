#!/usr/bin/env sh
set -ex

# Download the data.
code_version=$1
local_path=$2

curl -L -o $local_path https://github.com/spacelift-io/ec2-workerpool-autoscaler/releases/download/v${code_version}/ec2-workerpool-autoscaler_${code_version}_linux_amd64.zip

source_code_hash=$(openssl dgst -binary -sha256 $local_path | openssl base64 -A)

echo "{\"source_code_hash\": \"${source_code_hash}\"}"
