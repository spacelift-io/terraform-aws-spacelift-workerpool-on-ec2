#!/usr/bin/env sh
set -ex

# Download the data.
code_version=$1
code_architecture=$2

curl -L -o lambda.zip "https://github.com/spacelift-io/ec2-workerpool-autoscaler/releases/download/${code_version}/ec2-workerpool-autoscaler_linux_${code_architecture}.zip"

mkdir -p lambda
cd lambda
unzip -o ../lambda.zip
rm ../lambda.zip
