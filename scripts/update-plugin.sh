#!/bin/bash

# Script that updates the pubspec.yaml file in the SDK to newest semantic version.
#
# Designed to be run from CI server or manually.
#
# Use script: ./scripts/update-plugin.sh "0.1.1"

set -e

NEW_VERSION="$1"

echo "Updating files to new version: $NEW_VERSION"

echo "Updating customer_io_plugin_version.dart"
# Given line: `const version = "1.0.0-alpha.4";`
# Regex string will match the line of the file that we can then substitute.
sd 'const version = "(.*)"' "const version = \"$NEW_VERSION\"" "./lib/customer_io_plugin_version.dart"

echo "Check file, you should see version inside has been updated!"