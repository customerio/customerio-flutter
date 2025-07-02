#!/bin/bash

# Demo script to show release notes extraction capability
# This demonstrates how the automation will work with real Customer.io releases

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

# Check if GitHub CLI is available
check_gh_cli() {
  if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) not found. Please install it to run this demo."
    log_info "Visit: https://cli.github.com/"
    exit 1
  fi
}

# Get latest release info
get_latest_release_info() {
  local repo=$1
  
  log_info "Fetching latest release from $repo..."
  
  local release_info=$(gh api "repos/$repo/releases/latest" 2>/dev/null)
  
  if [[ -n "$release_info" ]]; then
    local tag_name=$(echo "$release_info" | jq -r '.tag_name')
    local name=$(echo "$release_info" | jq -r '.name')
    local body=$(echo "$release_info" | jq -r '.body')
    local html_url=$(echo "$release_info" | jq -r '.html_url')
    local published_at=$(echo "$release_info" | jq -r '.published_at')
    
    echo "📦 Release: $name"
    echo "🏷️  Tag: $tag_name"
    echo "📅 Published: $published_at"
    echo "🔗 URL: $html_url"
    echo ""
    echo "📋 Release Notes:"
    echo "=================="
    echo "$body"
    echo ""
    
    # Extract key changes
    log_info "Extracting key changes for automation..."
    local key_changes=$(echo "$body" | grep -E '^[-*]\s+|^#{1,3}\s+|^\d+\.\s+|^(Added|Fixed|Changed|Updated|Improved|Enhanced)[:]\s*' | \
      sed 's/^[-*#]\s*/- /' | \
      sed 's/^[0-9]\+\.\s*/- /' | \
      head -5)
    
    if [[ -n "$key_changes" ]]; then
      echo "🔍 Extracted Key Changes:"
      echo "$key_changes"
    else
      log_warning "No structured changes found in release notes"
    fi
    
    echo ""
    echo "================================"
    echo ""
  else
    log_error "Could not fetch release information"
  fi
}

# Simulate PR content generation
simulate_pr_content() {
  local ios_version=$1
  local android_version=$2
  
  log_info "Simulating PR content generation..."
  
  echo "📝 Generated PR Content:"
  echo "========================"
  echo ""
  echo "**Title:** chore: update Customer.io native SDKs (iOS $ios_version, Android $android_version)"
  echo ""
  echo "**Description:**"
  echo "## Summary"
  echo ""
  echo "Automated update of Customer.io native SDK dependencies:"
  echo ""
  echo "- **iOS SDK**: 3.10.5 → $ios_version ([Release Notes](https://github.com/customerio/customerio-ios/releases/tag/v$ios_version))"
  echo "- **Android SDK**: 4.6.3 → $android_version ([Release Notes](https://github.com/customerio/customerio-android/releases/tag/v$android_version))"
  echo ""
  echo "## Key Changes"
  echo ""
  echo "### iOS SDK $ios_version"
  echo "- Enhanced push notification reliability"
  echo "- Improved battery optimization for background tasks"
  echo "- Fixed compatibility issues with iOS 17+"
  echo "- Updated minimum deployment target"
  echo ""
  echo "### Android SDK $android_version"
  echo "- Optimized network request handling"
  echo "- Enhanced in-app message rendering performance"
  echo "- Fixed memory leaks in long-running sessions"
  echo "- Added support for Android 14 features"
  echo ""
  echo "## Testing"
  echo ""
  echo "- ✅ Flutter analysis passed"
  echo "- ✅ Unit tests passed"
  echo "- ✅ iOS compilation verified"
  echo "- ✅ Android compilation verified"
  echo "- ✅ Sample app builds successfully"
  echo ""
  echo "## Migration Notes"
  echo ""
  echo "This update maintains API compatibility. Please test your integration thoroughly and review the release notes linked above for any specific changes that might affect your implementation."
  echo ""
  echo "---"
  echo "*🤖 This PR was automatically generated and tested*"
}

main() {
  echo "🚀 Customer.io Native SDK Release Notes Demo"
  echo "============================================="
  echo ""
  
  check_gh_cli
  
  # Demo with Customer.io iOS SDK
  log_success "Demonstrating iOS SDK release notes extraction"
  get_latest_release_info "customerio/customerio-ios"
  
  # Demo with Customer.io Android SDK (if available)
  log_success "Demonstrating Android SDK release notes extraction"
  get_latest_release_info "customerio/customerio-android"
  
  # Show simulated PR content
  log_success "Demonstrating PR content generation"
  simulate_pr_content "3.11.0" "4.7.0"
  
  echo ""
  log_success "Demo completed! This shows how the automation will:"
  echo "  1. 🔍 Detect new releases automatically"
  echo "  2. 📋 Extract meaningful changes from release notes"
  echo "  3. 📝 Generate professional PR descriptions"
  echo "  4. 🔗 Link to original release notes for full details"
  echo ""
  log_info "To run the actual automation:"
  echo "  • Set up the GitHub workflow: .github/workflows/auto-update-native-sdks.yml"
  echo "  • Manual updates: ./scripts/update-native-sdk-versions.sh --auto"
  echo "  • Or trigger via GitHub Actions UI"
}

main "$@"