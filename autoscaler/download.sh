#!/usr/bin/env sh
set -ex

# Download the data.
code_version=$1
code_architecture=$2
downloadFolder=$3

download_url="https://github.com/spacelift-io/ec2-workerpool-autoscaler/releases/download/${code_version}/ec2-workerpool-autoscaler_linux_${code_architecture}.zip"

mkdir -p "$downloadFolder"
cd "$downloadFolder"
curl -L -O "$download_url"
