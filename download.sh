#!/usr/bin/env sh
set -ex

# Download the data.
code_version=$1
export code_architecture=$2

if [ "$code_version" != "latest" ]; then
  # If the code version is not latest, we don't need to hit the github api.
  download_url="https://github.com/spacelift-io/ec2-workerpool-autoscaler/releases/download/${code_version}/ec2-workerpool-autoscaler_linux_${code_architecture}.zip"
else
  # Make a temporary file to store the headers in
  tmpfile=$(mktemp /tmp/spacelift-request-headers.XXXXXX)
  # If GITHUB_TOKEN is set, we can benefit from its higher rate limit
  if [ -n "${GITHUB_TOKEN}" ]; then
    request=$(curl -D "$tmpfile" -X GET --header "Authorization: Bearer ${GITHUB_TOKEN}" -sS "https://api.github.com/repos/spacelift-io/ec2-workerpool-autoscaler/releases/latest")
  else
    request=$(curl -D "$tmpfile" -X GET -sS "https://api.github.com/repos/spacelift-io/ec2-workerpool-autoscaler/releases/latest")
  fi
  ratelimit=$(cat "$tmpfile" | grep x-ratelimit-remaining | awk '{print $2}' | tr -d '\012\015')
  rm "$tmpfile"
  if [ $ratelimit = "0" ]; then
      echo "Github API rate limit exceeded, cannot find latest version. Please try again later or version pin the module."
      exit 1
  else
    echo "Github API rate limit remaining: '$ratelimit'"

    # Use printf here because echo will evaluate new lines which breaks the json formatting for jq
    release=$(printf '%s' "$request" | jq -r --arg ZIP "ec2-workerpool-autoscaler_linux_$code_architecture.zip" '.assets[] | select(.name==$ZIP)')

    release_date=$(echo $release | jq -r '.created_at')
    download_url=$(echo $release | jq -r '.browser_download_url')

    echo "Downloading Details:"
    echo "  Release Name: $code_version"
    echo "  Release Date: $release_date"
    echo "  Download URL: $download_url"
  fi
fi

curl -L -O "$download_url"
