#!/bin/bash

# Script that updates the pubspec.yaml file in the SDK to newest semantic version.
#
# Designed to be run from CI server or manually.
#
# Use script: ./scripts/update-version.sh "0.1.1"

set -e

NEW_VERSION="$1"

echo "Updating files to new version: $NEW_VERSION"

echo "Updating pubspec.yaml"
sd 'version: (.*)' "version: $NEW_VERSION" pubspec.yaml

echo "Check file, you should see version inside has been updated!"

echo "Now, updating plugin...."
./scripts/update-plugin.sh "$NEW_VERSION"
