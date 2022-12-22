#!/bin/bash

# Script that updates the pubspec.yaml file in the SDK to newest semantic version.
#
# Designed to be run from CI server or manually.
#
# Use script: ./scripts/update-version.sh "0.1.1"

set -e

NEW_VERSION="$1"

echo "Updating pubspec.yaml to new version: $NEW_VERSION"

sed -i 's/^\(version: \).*$/\1'"$NEW_VERSION"'/' pubspec.yaml

echo "Check pubspec.yaml file. You should see version inside has been updated!"