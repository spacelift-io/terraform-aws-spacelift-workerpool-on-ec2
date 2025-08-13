#!/usr/bin/env bash

# This script zips the lifecycle manager so we dont have to do it at runtime.
# it makes the terraform apply slightly faster and we dont need to worry about it being
# available between runs.

# Create reproducible zip by setting timestamp to a fixed date
export TZ=UTC
zip -X ./ec2-workerpool-lifecycle-manager.zip ./main.py
