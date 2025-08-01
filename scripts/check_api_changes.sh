#!/bin/bash

# Customer.io Flutter SDK API Change Detection Tool
# Usage: ./check_api_changes.sh

set -e

# Define file paths
CURRENT_API_FILE="customerio-flutter.api"
BACKUP_API_FILE="customerio-flutter.api.backup"

# Exit codes
EXIT_NO_CHANGES=0
EXIT_CHANGES_DETECTED=1
EXIT_ERROR=2

# Function to cleanup temporary files
cleanup() {
    rm -f "$BACKUP_API_FILE"
}

# Set up cleanup on exit
trap cleanup EXIT

# Check if current API file exists
if [ ! -f "$CURRENT_API_FILE" ]; then
    echo "❌ Error: Current API file '$CURRENT_API_FILE' not found"
    echo "   Run './scripts/extract_api.sh' first to generate the initial API file"
    exit $EXIT_ERROR
fi

# Backup current API file
cp "$CURRENT_API_FILE" "$BACKUP_API_FILE"

# Generate new API file using existing extraction script
./scripts/extract_api.sh > /dev/null 2>&1

# Compare API files (backup vs newly generated current file)
if cmp -s "$BACKUP_API_FILE" "$CURRENT_API_FILE"; then
    echo "✅ No API changes detected"
    exit $EXIT_NO_CHANGES
else
    echo "🚨 API changes detected!"
    echo ""
    echo "📊 Detailed differences:"
    echo "===================="
    
    # Show detailed diff
    diff --unified=3 "$BACKUP_API_FILE" "$CURRENT_API_FILE" || true
    
    echo ""
    echo "===================="
    echo "❗ Please review the changes carefully before merging."
    echo ""
    echo "💡 If these changes are intentional, update the baseline API file:"
    echo "   ./scripts/extract_api.sh"
    echo ""
    echo "   This will regenerate customerio-flutter.api with the current API surface."
    
    exit $EXIT_CHANGES_DETECTED
fi 