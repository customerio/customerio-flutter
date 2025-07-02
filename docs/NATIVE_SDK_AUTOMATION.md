# Native SDK Automation Guide

This guide explains the automated workflow for updating Customer.io native SDK versions in the Flutter plugin.

## 🚀 Overview

The automation system automatically:
- 🔍 **Monitors** native SDK releases (iOS & Android)
- 📝 **Creates PRs** with version updates
- 📋 **Extracts** release notes for PR descriptions
- 🧪 **Tests** compilation and builds
- 👥 **Assigns** reviewers automatically
- 📊 **Provides** detailed workflow summaries

## 🏗️ Architecture

### Components

1. **GitHub Action Workflow** (`.github/workflows/auto-update-native-sdks.yml`)
   - Scheduled daily checks for new releases
   - Manual trigger support
   - Comprehensive testing pipeline

2. **Update Script** (`scripts/update-native-sdk-versions.sh`)
   - Manual version updates
   - AI-powered changelog generation
   - Local development support

3. **Configuration** (`.github/native-sdk-automation.yml`)
   - Customizable behavior
   - Reviewer settings
   - Testing preferences

## 📋 Setup Instructions

### 1. Required Secrets

**No secrets required!** 🎉

The workflow uses GitHub's built-in `GITHUB_TOKEN` which is automatically provided to all GitHub Actions. No manual setup needed.

### 2. Repository Permissions

Ensure the GitHub Action has these permissions:
- `contents: write` - To create branches and commits
- `pull-requests: write` - To create PRs
- `issues: write` - To create issues on failures

### 3. Team Configuration

Update the reviewers in the workflow file:

```yaml
--reviewer "customerio/mobile-team" \
```

Or configure in `.github/native-sdk-automation.yml`:

```yaml
pull_request:
  reviewers:
    - "your-team/mobile-reviewers"
    - "specific-username"
```

## 🎯 Usage

### Automatic Updates

The workflow runs automatically:
- **Daily at 9 AM UTC** (configurable)
- **On new native SDK releases** (when properly configured)

### Manual Triggers

#### Via GitHub Actions UI:
1. Go to Actions tab
2. Select "Auto-update Native SDKs"
3. Click "Run workflow"
4. Optionally specify versions

#### Via Command Line:
```bash
# Auto-detect latest versions
./scripts/update-native-sdk-versions.sh --auto

# Specific versions
./scripts/update-native-sdk-versions.sh --ios=3.11.0 --android=4.7.0

# With release notes changelog generation  
./scripts/update-native-sdk-versions.sh --auto --changelog

# Force update even if versions haven't changed
./scripts/update-native-sdk-versions.sh --ios=3.10.5 --force
```

### GitHub CLI Integration:
```bash
# Trigger workflow with specific versions
gh workflow run auto-update-native-sdks.yml \
  -f ios_version=3.11.0 \
  -f android_version=4.7.0

# Force update
gh workflow run auto-update-native-sdks.yml \
  -f force_update=true
```

## 🔧 Configuration

### Monitoring Settings

```yaml
# .github/native-sdk-automation.yml
monitoring:
  repositories:
    ios: "customerio/customerio-ios"
    android: "customerio/customerio-android"
  schedule: "0 9 * * *"  # Daily at 9 AM UTC
```

### Update Behavior

```yaml
updates:
  auto_create_pr: true
  skip_prerelease: true
  max_version_jump:
    major: 1  # Allow max 1 major version jump
    minor: 10
    patch: 100
```

### Release Notes Configuration

```yaml
release_notes:
  enabled: true
  max_changes_per_sdk: 5
  extraction_patterns:
    - '^[-*]\s+(.+)'           # Bullet points
    - '^#{1,3}\s+(.+)'         # Headers
  min_change_length: 10
```

## 🧪 Testing Pipeline

The automation includes comprehensive testing:

### Pre-PR Creation:
1. **Flutter Analysis** - `flutter analyze --no-fatal-infos`
2. **Unit Tests** - `flutter test`
3. **iOS Build** - `flutter build ios --no-codesign --debug`
4. **Android Build** - `flutter build apk --debug`
5. **Sample App Build** - Full app compilation test

### Manual Testing:
```bash
# Run the same tests locally
flutter pub get
flutter analyze --no-fatal-infos
flutter test

# Test sample app
cd apps/amiapp_flutter
flutter build ios --no-codesign --debug
flutter build apk --debug
```

## 📊 Monitoring & Alerts

### Workflow Status

Check workflow status:
- GitHub Actions tab shows recent runs
- Email notifications on failures (if configured)
- Slack notifications (if configured)

### Failed Updates

When updates fail:
1. **GitHub Issue** created automatically
2. **Workflow summary** shows detailed error info
3. **Logs** available in Actions tab

### Success Notifications

Successful updates provide:
- **PR link** in workflow summary
- **Version diff** in PR description
- **Test results** confirmation

## 🔍 Troubleshooting

### Common Issues

#### 1. Authentication Errors
```
Error: Request failed due to following response errors: Your token has not been granted the required scopes
```

**Solution**: Ensure `GITHUB_TOKEN` has required permissions

#### 2. AI Generation Fails
```
AI generation failed, using fallback
```

**Solution**: 
- Check `ANTHROPIC_API_KEY` is set correctly
- Verify API key has sufficient credits
- Fallback content will be used automatically

#### 3. Build Failures
```
flutter analyze failed with exit code 3
```

**Solution**: 
- Check if the new SDK versions introduce breaking changes
- Review analyzer output in workflow logs
- May need manual intervention for major updates

#### 4. No Updates Detected
```
No updates needed. Current versions are up to date.
```

**Possible causes**:
- Repositories might be private or renamed
- Rate limiting on GitHub API
- Releases might be pre-release versions (skipped by default)

### Debug Mode

Enable debug mode in configuration:

```yaml
debug:
  verbose: true
  dry_run: true  # Test without creating actual PRs
  keep_temp_files: true
```

### Manual Verification

Verify current versions:
```bash
# Check current iOS version
grep 'native_sdk_version:' pubspec.yaml

# Check current Android version
grep 'def cioVersion = ' android/build.gradle

# Check latest releases manually
gh release list --repo customerio/customerio-ios
gh release list --repo customerio/customerio-android
```

## 🚦 Best Practices

### 1. Review Process
- **Always review** automated PRs thoroughly
- **Test manually** with your specific use cases
- **Check release notes** of native SDKs for breaking changes

### 2. Version Management
- **Pin specific versions** rather than using version ranges
- **Test incrementally** rather than jumping multiple major versions
- **Coordinate updates** with your release schedule

### 3. Monitoring
- **Subscribe to notifications** from native SDK repositories
- **Review automation logs** regularly
- **Keep configuration up to date**

### 4. Emergency Procedures
- **Disable automation** if issues arise: comment out the schedule in the workflow
- **Revert quickly** if critical issues found: create manual revert PR
- **Communicate updates** to your team promptly

## 📚 Advanced Usage

### Custom Version Detection

Modify the workflow to use custom logic:

```javascript
// In check_releases.js section
async function getLatestRelease(owner, repo) {
  // Custom logic for version detection
  // e.g., filter by specific patterns, check specific branches
}
```

### Integration with Release Process

Coordinate with your release workflow:

```yaml
# In your main release workflow
- name: Check for pending SDK updates
  run: |
    pending_prs=$(gh pr list --label "native-sdk" --state open)
    if [ -n "$pending_prs" ]; then
      echo "⚠️ Pending native SDK updates found"
      echo "$pending_prs"
    fi
```

### Custom Notifications

Add Slack/Discord notifications:

```yaml
- name: Notify team
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: "Native SDK update completed"
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

## 🔗 Related Documentation

- [Customer.io iOS SDK](https://github.com/customerio/customerio-ios)
- [Customer.io Android SDK](https://github.com/customerio/customerio-android)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter CI/CD Best Practices](https://docs.flutter.dev/deployment/cd)

## 📞 Support

For issues with this automation:
1. Check the [troubleshooting section](#troubleshooting)
2. Review workflow logs in GitHub Actions
3. Create an issue in this repository
4. Contact the mobile team for urgent issues

---

*This automation is designed to make native SDK updates seamless and reliable. Happy coding! 🚀*