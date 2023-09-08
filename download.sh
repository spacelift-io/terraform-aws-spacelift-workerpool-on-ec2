#!/usr/bin/env sh
set -ex

# Download the data.
code_version=$1

curl -L -o lambda.zip https://github.com/spacelift-io/ec2-workerpool-autoscaler/releases/download/v${code_version}/ec2-workerpool-autoscaler_${code_version}_linux_amd64.zip

mkdir lambda
cd lambda
unzip ../lambda.zip
