#!/bin/bash

# Customer.io Flutter SDK API Extraction Tool
# Usage: ./extract_api.sh

echo "🔍 Extracting Customer.io Flutter SDK API..."

# Remove existing API file to ensure fresh generation
echo "🗑️ Removing existing API file..."
rm -f customerio-flutter.api

# Extract full API using dart_apitool
echo "📝 Running dart_apitool extraction..."
flutter pub run dart_apitool:main extract --input . --output api_current.json --force-use-flutter

# Generate filtered API format
echo "🎯 Generating API format..."
dart run scripts/filter_api.dart api_current.json > customerio-flutter.api

# Verify the API file was created
if [ ! -f customerio-flutter.api ]; then
    echo "❌ Error: Failed to generate customerio-flutter.api"
    rm -f api_current.json
    exit 1
fi

echo "✅ API saved to customerio-flutter.api"

# Clean up temporary files
echo "🧹 Cleaning up temporary files..."
rm -f api_current.json
echo "✅ Temporary files removed"

echo "🚀 API extraction complete!"
