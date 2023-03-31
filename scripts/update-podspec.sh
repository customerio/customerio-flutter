#!/bin/bash

# Script that updates the pubspec.yaml file in the SDK to newest semantic version.
#
# Designed to be run from CI server or manually.
#
# Use script: ./scripts/update-podspec.sh "0.1.1"

set -e

NEW_VERSION="$1"

echo "Updating files to new version: $NEW_VERSION"

echo "Updating customer_io.podspec"
LINE_PATTERN="s.version\s*=.*"
sed -i "s/$LINE_PATTERN/s.version     = \'$NEW_VERSION\'/" "./ios/customer_io.podspec"

echo "Check file, you should see version inside has been updated!"