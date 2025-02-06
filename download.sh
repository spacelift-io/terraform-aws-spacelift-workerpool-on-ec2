#!/usr/bin/env sh
set -ex

# Download the data.
code_version=$1
export code_architecture=$2

if [ "$code_version" != "latest" ]; then
  code_version="tags/$code_version"
fi

release=$(curl -sS "https://api.github.com/repos/spacelift-io/ec2-workerpool-autoscaler/releases/${code_version}" | jq -r --arg ZIP "ec2-workerpool-autoscaler_linux_$code_architecture.zip" '.assets[] | select(.name==$ZIP)')

release_date=$(echo $release | jq -r '.created_at')
download_url=$(echo $release | jq -r '.browser_download_url')

echo "Downloading Details:"
echo "  Release Name: $code_version"
echo "  Release Date: $release_date"
echo "  Download URL: $download_url"

curl -L -o lambda.zip $download_url

mkdir -p lambda
cd lambda
unzip -o ../lambda.zip
rm ../lambda.zip