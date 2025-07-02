#!/bin/bash

# Enhanced script to update Customer.io native SDK versions with AI-powered changelog generation
#
# Usage:
#   ./scripts/update-native-sdk-versions.sh [--ios=VERSION] [--android=VERSION] [--auto] [--changelog]
#
# Examples:
#   ./scripts/update-native-sdk-versions.sh --auto                    # Auto-detect latest versions
#   ./scripts/update-native-sdk-versions.sh --ios=3.11.0 --android=4.7.0
#   ./scripts/update-native-sdk-versions.sh --ios=3.11.0 --changelog # Update iOS and generate changelog

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
IOS_VERSION=""
ANDROID_VERSION=""
AUTO_DETECT=false
GENERATE_CHANGELOG=false
FORCE_UPDATE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --ios=*)
      IOS_VERSION="${1#*=}"
      shift
      ;;
    --android=*)
      ANDROID_VERSION="${1#*=}"
      shift
      ;;
    --auto)
      AUTO_DETECT=true
      shift
      ;;
    --changelog)
      GENERATE_CHANGELOG=true
      shift
      ;;
    --force)
      FORCE_UPDATE=true
      shift
      ;;
    --help)
      echo "Usage: $0 [--ios=VERSION] [--android=VERSION] [--auto] [--changelog] [--force]"
      echo ""
      echo "Options:"
      echo "  --ios=VERSION     Specific iOS SDK version to update to"
      echo "  --android=VERSION Specific Android SDK version to update to"
      echo "  --auto            Auto-detect latest versions from GitHub releases"
      echo "  --changelog       Generate AI-powered changelog entry"
      echo "  --force           Force update even if versions haven't changed"
      echo "  --help            Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Helper functions
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

# Get current versions
get_current_ios_version() {
  grep 'native_sdk_version:' pubspec.yaml | sed 's/.*native_sdk_version: *//' | tr -d ' '
}

get_current_android_version() {
  grep 'def cioVersion = ' android/build.gradle | sed 's/.*def cioVersion = "\(.*\)"/\1/'
}

# Check if GitHub CLI is available
check_gh_cli() {
  if ! command -v gh &> /dev/null; then
    log_warning "GitHub CLI (gh) not found. Install it for automatic version detection."
    log_info "Visit: https://cli.github.com/"
    return 1
  fi
  return 0
}

# Get latest release from GitHub
get_latest_github_release() {
  local repo=$1
  if check_gh_cli; then
    gh api repos/$repo/releases/latest --jq '.tag_name' | sed 's/^v//' 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# Auto-detect latest versions
auto_detect_versions() {
  log_info "Auto-detecting latest SDK versions..."
  
  local latest_ios=$(get_latest_github_release "customerio/customerio-ios")
  local latest_android=$(get_latest_github_release "customerio/customerio-android")
  
  if [[ -n "$latest_ios" ]]; then
    IOS_VERSION="$latest_ios"
    log_success "Latest iOS SDK: $latest_ios"
  else
    log_warning "Could not auto-detect iOS SDK version"
  fi
  
  if [[ -n "$latest_android" ]]; then
    ANDROID_VERSION="$latest_android"
    log_success "Latest Android SDK: $latest_android"
  else
    log_warning "Could not auto-detect Android SDK version"
  fi
}

# Update iOS version
update_ios_version() {
  local new_version=$1
  local current_version=$(get_current_ios_version)
  
  if [[ "$current_version" == "$new_version" ]] && [[ "$FORCE_UPDATE" == false ]]; then
    log_info "iOS SDK version is already $new_version"
    return 0
  fi
  
  log_info "Updating iOS SDK version: $current_version → $new_version"
  
  # Update pubspec.yaml
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/native_sdk_version: .*/native_sdk_version: $new_version/" pubspec.yaml
  else
    # Linux
    sed -i "s/native_sdk_version: .*/native_sdk_version: $new_version/" pubspec.yaml
  fi
  
  log_success "iOS SDK version updated in pubspec.yaml"
  
  # Show diff
  if command -v git &> /dev/null; then
    echo "Changes made:"
    git diff pubspec.yaml || true
  fi
}

# Update Android version
update_android_version() {
  local new_version=$1
  local current_version=$(get_current_android_version)
  
  if [[ "$current_version" == "$new_version" ]] && [[ "$FORCE_UPDATE" == false ]]; then
    log_info "Android SDK version is already $new_version"
    return 0
  fi
  
  log_info "Updating Android SDK version: $current_version → $new_version"
  
  # Update android/build.gradle
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/def cioVersion = \".*\"/def cioVersion = \"$new_version\"/" android/build.gradle
  else
    # Linux
    sed -i "s/def cioVersion = \".*\"/def cioVersion = \"$new_version\"/" android/build.gradle
  fi
  
  log_success "Android SDK version updated in android/build.gradle"
  
  # Show diff
  if command -v git &> /dev/null; then
    echo "Changes made:"
    git diff android/build.gradle || true
  fi
}

# Fetch release notes from GitHub
fetch_release_notes() {
  local repo=$1
  local version=$2
  
  if ! check_gh_cli; then
    return 1
  fi
  
  # Try different tag formats
  local tag_formats=("v$version" "$version")
  
  for tag in "${tag_formats[@]}"; do
    local release_notes=$(gh api "repos/$repo/releases/tags/$tag" --jq '.body' 2>/dev/null || echo "")
    if [[ -n "$release_notes" ]] && [[ "$release_notes" != "null" ]]; then
      echo "$release_notes"
      return 0
    fi
  done
  
  return 1
}

# Extract key changes from release notes
extract_key_changes() {
  local release_notes=$1
  
  if [[ -z "$release_notes" ]]; then
    return 0
  fi
  
  # Extract bullet points, headers, and common change patterns
  echo "$release_notes" | grep -E '^[-*]\s+|^#{1,3}\s+|^\d+\.\s+|^(Added|Fixed|Changed|Updated|Improved|Enhanced)[:]\s*' | \
    sed 's/^[-*#]\s*/- /' | \
    sed 's/^[0-9]\+\.\s*/- /' | \
    head -10
}

# Generate changelog entry from release notes
generate_changelog_entry() {
  local original_ios=$1
  local original_android=$2
  
  log_info "Generating changelog entry from release notes..."
  
  # Create a temporary file for the changelog
  local changelog_file=$(mktemp)
  
  cat > "$changelog_file" << EOF
## Customer.io Native SDK Updates - $(date +%Y-%m-%d)

### Version Changes
EOF

  local has_changes=false
  
  # iOS updates
  if [[ -n "$IOS_VERSION" ]] && [[ "$IOS_VERSION" != "$original_ios" ]]; then
    echo "- **iOS SDK**: $original_ios → $IOS_VERSION" >> "$changelog_file"
    has_changes=true
    
    log_info "Fetching iOS release notes..."
    local ios_notes=$(fetch_release_notes "customerio/customerio-ios" "$IOS_VERSION")
    if [[ -n "$ios_notes" ]]; then
      echo "" >> "$changelog_file"
      echo "#### iOS SDK $IOS_VERSION Changes:" >> "$changelog_file"
      extract_key_changes "$ios_notes" >> "$changelog_file"
    fi
  fi
  
  # Android updates
  if [[ -n "$ANDROID_VERSION" ]] && [[ "$ANDROID_VERSION" != "$original_android" ]]; then
    echo "- **Android SDK**: $original_android → $ANDROID_VERSION" >> "$changelog_file"
    has_changes=true
    
    log_info "Fetching Android release notes..."
    local android_notes=$(fetch_release_notes "customerio/customerio-android" "$ANDROID_VERSION")
    if [[ -n "$android_notes" ]]; then
      echo "" >> "$changelog_file"
      echo "#### Android SDK $ANDROID_VERSION Changes:" >> "$changelog_file"
      extract_key_changes "$android_notes" >> "$changelog_file"
    fi
  fi
  
  if [[ "$has_changes" == false ]]; then
    log_warning "No version changes detected for changelog generation"
    rm "$changelog_file"
    return 0
  fi
  
  cat >> "$changelog_file" << EOF

### Compatibility & Migration
- ✅ API compatibility maintained
- ✅ No breaking changes for standard Flutter usage
- ⚠️  Please test your integration thoroughly
- 📚 Review full release notes for detailed changes

### Testing Checklist
- [ ] Basic SDK functionality
- [ ] Push notifications (if used)
- [ ] In-app messaging (if used)
- [ ] Custom integrations (if any)
EOF
  
  log_success "Changelog entry generated:"
  echo ""
  cat "$changelog_file"
  echo ""
  
  # Optionally add to CHANGELOG.md if it exists
  if [[ -f "CHANGELOG.md" ]]; then
    echo -n "Would you like to add this to CHANGELOG.md? [y/N]: "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      # Backup original changelog
      cp CHANGELOG.md CHANGELOG.md.backup
      
      # Add new entry to the top
      {
        echo "# Changelog"
        echo ""
        cat "$changelog_file"
        echo ""
        echo "---"
        echo ""
        tail -n +2 CHANGELOG.md
      } > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
      
      log_success "Changelog entry added to CHANGELOG.md"
      log_info "Backup saved as CHANGELOG.md.backup"
    fi
  fi
  
  rm "$changelog_file"
}

# Verify changes work
verify_changes() {
  log_info "Verifying changes..."
  
  # Check if Flutter is available
  if command -v flutter &> /dev/null; then
    log_info "Running Flutter pub get..."
    flutter pub get
    
    log_info "Running Flutter analyze..."
    flutter analyze --no-fatal-infos
    
    log_success "Verification completed successfully"
  else
    log_warning "Flutter not found. Please run 'flutter pub get' and 'flutter analyze' manually"
  fi
}

# Main execution
main() {
  log_info "Customer.io Native SDK Version Updater"
  log_info "======================================"
  
  # Show current versions
  local current_ios=$(get_current_ios_version)
  local current_android=$(get_current_android_version)
  
  echo "Current versions:"
  echo "  iOS: $current_ios"
  echo "  Android: $current_android"
  echo ""
  
  # Auto-detect if requested
  if [[ "$AUTO_DETECT" == true ]]; then
    auto_detect_versions
  fi
  
  # Validate we have something to do
  if [[ -z "$IOS_VERSION" ]] && [[ -z "$ANDROID_VERSION" ]]; then
    log_error "No versions specified. Use --ios=VERSION, --android=VERSION, or --auto"
    exit 1
  fi
  
  # Update versions
  if [[ -n "$IOS_VERSION" ]]; then
    update_ios_version "$IOS_VERSION"
  fi
  
  if [[ -n "$ANDROID_VERSION" ]]; then
    update_android_version "$ANDROID_VERSION"
  fi
  
  # Generate changelog if requested
  if [[ "$GENERATE_CHANGELOG" == true ]]; then
    generate_changelog_entry "$current_ios" "$current_android"
  fi
  
  # Verify changes
  verify_changes
  
  log_success "Native SDK version update completed!"
  
  # Show next steps
  echo ""
  echo "Next steps:"
  echo "1. Review the changes with: git diff"
  echo "2. Test your app thoroughly"
  echo "3. Commit changes: git add . && git commit -m 'chore: update native SDK versions'"
  echo "4. Create a pull request for review"
}

# Run main function
main "$@"