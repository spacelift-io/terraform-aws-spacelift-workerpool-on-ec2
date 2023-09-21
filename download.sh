#!/usr/bin/env sh
set -ex

# Download the data.
code_version=$1
local_path=$2

curl -L -o ${local_path}/lambda.zip https://github.com/spacelift-io/ec2-workerpool-autoscaler/releases/download/${code_version}/ec2-workerpool-autoscaler_linux_amd64.zip

cd ../../../../../tmp
unzip lambda.zip
