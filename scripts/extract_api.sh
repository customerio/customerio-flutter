#!/bin/bash

# Customer.io Flutter SDK API Extraction Tool
# Usage: ./extract_api.sh

set -euo pipefail

echo "🔍 Extracting Customer.io Flutter SDK API..."

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/customerio-flutter-api.XXXXXX")"
temporary_api=""
cleanup() {
  rm -rf "$temporary_directory"
  if [ -n "$temporary_api" ]; then
    rm -f "$temporary_api"
  fi
}
trap cleanup EXIT

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

# Publish only a complete, nonempty extraction. The checked-in baseline remains
# byte-for-byte intact if either tool fails.
mv -f "$temporary_api" customerio-flutter.api
echo "✅ API saved to customerio-flutter.api"
echo "🚀 API extraction complete!"
