#!/bin/bash

# Customer.io Flutter SDK API Extraction Tool
# Usage: ./extract_api.sh

echo "🔍 Extracting Customer.io Flutter SDK API..."

# Extract full API using dart_apitool
echo "📝 Running dart_apitool extraction..."
dart-apitool extract --input . --output api_current.json --force-use-flutter

# Generate filtered API format
echo "🎯 Generating API format..."
dart run scripts/filter_api.dart api_current.json > customerio-flutter.api
echo "✅ API saved to customerio-flutter.api"

# Clean up temporary files
echo "🧹 Cleaning up temporary files..."
rm -f api_current.json
echo "✅ Temporary files removed"

echo "🚀 API extraction complete!"
