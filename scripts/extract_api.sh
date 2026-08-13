#!/bin/bash

# Customer.io Flutter SDK API Extraction Tool
# Usage: ./extract_api.sh

set -euo pipefail

echo "🔍 Extracting Customer.io Flutter SDK API..."

version_file="scripts/api-extraction-flutter-version.txt"
if [ ! -f "$version_file" ]; then
  echo "❌ Error: API extraction Flutter version file is missing" >&2
  exit 1
fi
expected_flutter_version="$(tr -d '[:space:]' < "$version_file")"
if [[ ! "$expected_flutter_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Error: invalid API extraction Flutter version: $expected_flutter_version" >&2
  exit 1
fi
actual_flutter_version="$(flutter --version | awk 'NR == 1 { print $2 }')"
if [ "$actual_flutter_version" != "$expected_flutter_version" ]; then
  echo "❌ Error: API extraction requires Flutter $expected_flutter_version; found $actual_flutter_version" >&2
  exit 1
fi

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/customerio-flutter-api.XXXXXX")"
temporary_api=""
cleanup() {
  rm -rf "$temporary_directory"
  if [ -n "$temporary_api" ]; then
    rm -f "$temporary_api"
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

temporary_model="$temporary_directory/api_current.json"

# Extract full API using dart_apitool
echo "📝 Running dart_apitool extraction..."
flutter pub run dart_apitool:main extract \
  --input . \
  --output "$temporary_model" \
  --force-use-flutter

if [ ! -s "$temporary_model" ]; then
  echo "❌ Error: dart_apitool produced no API model" >&2
  exit 1
fi

# Generate filtered API format
echo "🎯 Generating API format..."
# Keep the publication candidate beside the checked-in file so the final rename
# is atomic even when TMPDIR is mounted on another filesystem.
temporary_api="$(mktemp ./.customerio-flutter.api.XXXXXX)"
dart run scripts/filter_api.dart "$temporary_model" > "$temporary_api"

if [ ! -s "$temporary_api" ]; then
  echo "❌ Error: API filtering produced no public API" >&2
  exit 1
fi

chmod 644 "$temporary_api"

# Publish only a complete, nonempty extraction. The checked-in baseline remains
# byte-for-byte intact if either tool fails.
mv -f "$temporary_api" customerio-flutter.api
echo "✅ API saved to customerio-flutter.api"
echo "🚀 API extraction complete!"
