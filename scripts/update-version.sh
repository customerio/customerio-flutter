#!/bin/bash

# Script that updates the pubspec.yaml file in the SDK to newest semantic version.
#
# Designed to be run from CI server or manually.
#
# Use script: ./scripts/update-version.sh "0.1.1"

set -e

NEW_VERSION="$1"

echo "Starting version update to: $NEW_VERSION"

# Helper function to update version in a file and display the diff
update_version_in_file() {
  #  Parameters:
  #  $1: file_path: The path to the file to update
  #  $2: pattern: The regex pattern to match the line to update
  #  $3: replacement: The new version to replace the matched line with
  local file_path=$1
  local pattern=$2
  local replacement=$3

  echo -e "\nUpdating version in $file_path..."
  sd "$pattern" "$replacement" "$file_path"

  echo "Done! Showing changes in $file_path:"
  git diff "$file_path"
}

# Update version in pubspec.yaml
# Given line: `version: 1.3.5`
# Note: We are using ^ to match the start of the line to avoid matching other lines with version in them.
# e.g. `native_sdk_version: 3.5.7` should not be matched by this regex.
update_version_in_file "pubspec.yaml" "^(version: .*)" "version: $NEW_VERSION"

# Update version in customer_io_plugin_version.dart
# Given line: `const version = "1.3.5";`
update_version_in_file "./lib/customer_io_plugin_version.dart" "const version = \"(.*)\"" "const version = \"$NEW_VERSION\""

# Update version in customer_io_config.xml
SDK_CONFIG_CLIENT_VERSION_KEY="customer_io_wrapper_sdk_client_version"
# Given line: `<string name="customer_io_wrapper_sdk_client_version">1.3.5</string>`
update_version_in_file "android/src/main/res/values/customer_io_config.xml" "<string name=\"$SDK_CONFIG_CLIENT_VERSION_KEY\">.*</string>" "<string name=\"$SDK_CONFIG_CLIENT_VERSION_KEY\">$NEW_VERSION</string>"

echo -e "\nVersion update complete for targeted files."
