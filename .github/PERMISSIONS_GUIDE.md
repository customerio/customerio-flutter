# GitHub Permissions Guide for Native SDK Automation

## 🔐 Required Permissions Summary

### **Workflow Permissions (✅ Configured)**

```yaml
permissions:
  contents: write      # Create branches, modify files, commit, push
  pull-requests: write # Create and manage pull requests  
  issues: write        # Create issues on automation failures
  metadata: read       # Read repository metadata
  actions: read        # Read workflow information
```

### **GITHUB_TOKEN Capabilities**

The built-in `GITHUB_TOKEN` provides:
- ✅ **Read access** to public repositories (for release notes)
- ✅ **Full write access** to the current repository
- ✅ **API rate limit**: 1,000 requests per hour per repository
- ✅ **Automatic authentication** - no setup required

## 🎯 Permission Usage Breakdown

### **1. Repository Operations (Our Repo)**
| Operation | Permission Needed | Status |
|-----------|------------------|---------|
| Read files (pubspec.yaml, build.gradle) | `contents: read` | ✅ Covered by `contents: write` |
| Create branches | `contents: write` | ✅ Configured |
| Modify files | `contents: write` | ✅ Configured |
| Commit changes | `contents: write` | ✅ Configured |
| Push branches | `contents: write` | ✅ Configured |
| Create pull requests | `pull-requests: write` | ✅ Configured |
| Create issues (on failure) | `issues: write` | ✅ Configured |

### **2. External Repository Access**
| Operation | Permission Needed | Status |
|-----------|------------------|---------|
| Read customerio/customerio-ios releases | Public API access | ✅ Available via GITHUB_TOKEN |
| Read customerio/customerio-android releases | Public API access | ✅ Available via GITHUB_TOKEN |
| Extract release notes | Public API access | ✅ Available via GITHUB_TOKEN |

### **3. GitHub CLI Operations**
| Command | Permission Needed | Status |
|---------|------------------|---------|
| `gh pr create` | `pull-requests: write` | ✅ Configured |
| `gh api repos/...` | Various (handled by GITHUB_TOKEN) | ✅ Available |
| `gh workflow run` | `actions: write` | ✅ Configured for webhook |

## 🛡️ Security Considerations

### **Permissions Scope**
- ✅ **Minimal scope**: Only permissions needed for automation
- ✅ **Repository-specific**: Permissions limited to this repository
- ✅ **No secrets exposure**: Uses built-in GITHUB_TOKEN
- ✅ **Read-only external access**: Cannot modify external repositories

### **Built-in Safeguards**
- ✅ **Branch protection**: Cannot directly push to main branch
- ✅ **PR reviews required**: Team must approve all changes
- ✅ **Test validation**: Changes tested before PR creation
- ✅ **Audit trail**: All operations logged in workflow runs

## 🔍 Permission Verification

The workflow includes automatic permission testing:

```bash
# Tests performed on each run:
✅ Current repository access
✅ External repository read access  
✅ Pull request endpoint access
⚠️  Graceful fallback for API failures
```

### **What Happens if Permissions Fail?**

| Scenario | Behavior | Impact |
|----------|----------|---------|
| Cannot read external releases | Uses fallback content | ⚠️ PR created with basic info |
| Cannot create PR | Workflow fails with error | ❌ Manual intervention needed |
| Cannot push branch | Workflow fails with error | ❌ Check repository settings |
| API rate limit exceeded | Retries with backoff | ⏱️ Temporary delay |

## 🚨 Troubleshooting Permission Issues

### **Common Issues & Solutions**

#### **1. "Permission denied" accessing external repos**
```
Error: Request failed due to following response errors:
- message: API rate limit exceeded
```

**Solutions:**
- ✅ Wait for rate limit reset (1 hour)
- ✅ Use manual trigger with specific versions
- ✅ Workflow will use fallback content automatically

#### **2. "Insufficient permissions" for PR creation**
```
Error: Resource not accessible by integration
```

**Solutions:**
- ✅ Check repository settings → Actions → General
- ✅ Ensure "Read and write permissions" is enabled
- ✅ Verify workflow permissions are correctly set

#### **3. Branch protection rules preventing push**
```
Error: Required status check "build" must pass
```

**Solutions:**
- ✅ Ensure branch name pattern allows automation branches
- ✅ Consider exempting `auto-update/*` branches
- ✅ Or ensure all required checks pass in workflow

### **Repository Settings to Check**

1. **Settings → Actions → General**
   ```
   ✅ Workflow permissions: "Read and write permissions"
   ✅ Allow GitHub Actions to create pull requests: Enabled
   ```

2. **Settings → Branches (if main is protected)**
   ```
   ✅ Allow force pushes: Not needed (we use PRs)
   ✅ Restrict pushes: Should allow automation
   ✅ Required status checks: Will be handled by workflow
   ```

3. **Settings → Code security and analysis**
   ```
   ✅ No restrictions on automated dependency updates
   ```

## 📋 Permission Testing Commands

### **Manual Permission Testing**
```bash
# Test current repo access
gh auth status

# Test external repo access  
gh api repos/customerio/customerio-ios/releases/latest

# Test PR creation permissions (dry run)
gh api repos/OWNER/REPO/pulls --method GET

# Check rate limit status
gh api rate_limit
```

### **Workflow Permission Testing**
```bash
# Trigger permission verification manually
gh workflow run auto-update-native-sdks.yml

# Check workflow logs for permission errors
gh run list --workflow=auto-update-native-sdks.yml
```

## ✅ Pre-flight Checklist

Before enabling automation, verify:

- [ ] Repository has "Read and write" workflow permissions
- [ ] Branch protection allows automation (if main is protected)
- [ ] Team members are added as potential reviewers
- [ ] Workflow files are committed to main branch
- [ ] At least one manual test run completed successfully
- [ ] Permission verification step passes

## 🔄 Fallback Mechanisms

If permissions are insufficient, the automation includes fallbacks:

1. **API Access Fails** → Uses template PR content
2. **Rate Limit Hit** → Retries with exponential backoff  
3. **External Repo Access Denied** → Creates PR with basic version info
4. **PR Creation Fails** → Creates GitHub issue with details

## 📞 Support

**Permission Issues:**
1. Check this guide first
2. Review workflow logs in Actions tab
3. Test permissions manually with GitHub CLI
4. Contact repository administrators for settings changes

**Quick Fixes:**
- Most permission issues = Repository settings problem
- External API failures = Usually temporary, will auto-resolve
- Rate limit issues = Wait 1 hour or use manual version specification

---

*🔐 This automation follows GitHub security best practices with minimal required permissions.*