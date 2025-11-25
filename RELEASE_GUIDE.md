# Release Guide for react-native-auth-client

This guide provides step-by-step instructions for committing changes, pushing to GitHub, and publishing new versions to npm.

## Prerequisites

Before you start, ensure you have:
- Git configured with your GitHub credentials
- npm account with publish access to `react-native-auth-client`
- Two-factor authentication (2FA) enabled on npm (required for publishing)
- Access to your authenticator app for OTP codes

## Step-by-Step Release Process

### Step 1: Make Your Changes

Edit the files you need to modify in your codebase. Common areas include:
- `src/` - TypeScript/JavaScript source files
- `android/src/main/java/com/reactnativeauthclient/` - Android native code
- `ios/AuthClient/` - iOS native code

### Step 2: Check What Changed

Before committing, review your changes:

```bash
git status
```

This shows all modified files.

To see the actual changes in detail:

```bash
git diff
```

### Step 3: Stage Your Changes

Add the files you want to commit:

```bash
# Add specific files
git add path/to/file1.kt path/to/file2.swift

# Or add all changes
git add .
```

### Step 4: Commit Your Changes

Create a commit with a descriptive message:

```bash
git commit -m "Your commit message here

- Bullet point describing change 1
- Bullet point describing change 2"
```

**Commit Message Best Practices:**
- Use present tense ("Add feature" not "Added feature")
- Be descriptive but concise
- Start with a verb (Add, Fix, Update, Remove, Refactor)
- Include details in bullet points if needed

**Examples of good commit messages:**
```
Add removeListeners method for RN EventEmitter compatibility
```
```
Fix MainActor isolation error in iOS authentication flow
```
```
Update token refresh logic to handle edge cases

- Add retry mechanism for failed refreshes
- Improve error handling for network failures
```

### Step 5: Push to GitHub

Push your commit to the remote repository:

```bash
git push
```

If you're on a branch other than main:
```bash
git push origin your-branch-name
```

### Step 6: Publish to npm

There are two approaches to publishing:

#### Option A: Automated Release (Recommended)

Use the configured `release-it` tool for automated version bumping and publishing:

```bash
yarn release
```

This will:
1. Analyze your commits to determine the version bump (patch/minor/major)
2. Generate a changelog
3. Update `package.json` version
4. Build the library
5. Create a git commit and tag
6. Push to GitHub
7. Publish to npm
8. Create a GitHub release

**You'll be prompted to:**
- Confirm the version bump (0.2.6 → 0.2.7, for example)
- Confirm npm publish
- Enter your npm OTP code

#### Option B: Manual Publish

If you prefer manual control or `yarn release` fails:

1. **Bump the version manually:**

Edit `package.json` and increment the version:
```json
"version": "0.2.7"
```

Version format: `MAJOR.MINOR.PATCH`
- **PATCH** (0.2.6 → 0.2.7): Bug fixes, small changes
- **MINOR** (0.2.7 → 0.3.0): New features, backward compatible
- **MAJOR** (0.3.0 → 1.0.0): Breaking changes

2. **Build the library:**

```bash
yarn prepare
```

This runs the build process using `react-native-builder-bob`.

3. **Commit the version bump:**

```bash
git add package.json
git commit -m "Bump version to 0.2.7"
git push
```

4. **Create a git tag:**

```bash
git tag v0.2.7
git push origin v0.2.7
```

5. **Publish to npm:**

```bash
npm publish --access public
```

6. **Enter your OTP code when prompted:**

If you see an error requesting OTP:
```bash
npm publish --access public --otp=123456
```

Replace `123456` with the 6-digit code from your authenticator app.

### Step 7: Verify Publication

After publishing, verify your package is live:

1. **Check npm:**
```bash
npm view react-native-auth-client version
```

This should show your new version.

2. **Visit npm registry:**
https://www.npmjs.com/package/react-native-auth-client

3. **Test installation:**
```bash
npm info react-native-auth-client
```

## Common Scenarios

### Scenario 1: Quick Bug Fix

```bash
# 1. Fix the bug in your code
# 2. Check changes
git diff

# 3. Commit
git add .
git commit -m "Fix authentication timeout issue"

# 4. Push
git push

# 5. Release (patch version bump: 0.2.6 → 0.2.7)
yarn release
# Select "patch" when prompted
# Enter OTP when publishing
```

### Scenario 2: New Feature

```bash
# 1. Implement the feature
# 2. Check changes
git status
git diff

# 3. Commit
git add .
git commit -m "Add biometric authentication support

- Implement fingerprint authentication for Android
- Add Face ID support for iOS
- Update documentation with new API methods"

# 4. Push
git push

# 5. Release (minor version bump: 0.2.6 → 0.3.0)
yarn release
# Select "minor" when prompted
# Enter OTP when publishing
```

### Scenario 3: Breaking Change

```bash
# 1. Make breaking changes
# 2. Update documentation
# 3. Commit
git add .
git commit -m "BREAKING CHANGE: Refactor authentication API

- Remove deprecated authenticate() method
- Replace with authenticateWithCredentials()
- Update all method signatures for consistency"

# 4. Push
git push

# 5. Release (major version bump: 0.2.6 → 1.0.0)
yarn release
# Select "major" when prompted
# Enter OTP when publishing
```

## Troubleshooting

### Issue: OTP Error When Publishing

**Error:**
```
npm error code EOTP
npm error This operation requires a one-time password
```

**Solution:**
```bash
npm publish --access public --otp=123456
```
Get the OTP from your authenticator app and use it immediately (they expire quickly).

### Issue: Git Push Rejected

**Error:**
```
! [rejected] main -> main (fetch first)
```

**Solution:**
```bash
git pull --rebase
git push
```

### Issue: Version Already Published

**Error:**
```
npm error code E403
npm error You cannot publish over the previously published versions
```

**Solution:**
Bump the version in `package.json` to a higher number and try again.

### Issue: Build Fails Before Publish

**Error:**
```
ERROR Build failed
```

**Solution:**
```bash
# Clean and rebuild
yarn clean
yarn prepare
```

### Issue: Permission Denied on npm

**Error:**
```
npm error code E403
npm error 403 Forbidden
```

**Solution:**
1. Verify you're logged in to npm:
```bash
npm whoami
```

2. If not logged in:
```bash
npm login
```

3. Verify you have publish access to the package

## Quick Reference Commands

### Daily Development
```bash
git status                    # Check what changed
git diff                      # See detailed changes
git add .                     # Stage all changes
git commit -m "message"       # Commit changes
git push                      # Push to GitHub
```

### Release
```bash
yarn release                  # Automated release (recommended)
npm publish --otp=CODE        # Manual publish with OTP
npm view react-native-auth-client version  # Check published version
```

### Git Tags
```bash
git tag                       # List all tags
git tag v0.2.7               # Create new tag
git push origin v0.2.7       # Push tag to GitHub
git tag -d v0.2.7            # Delete local tag
git push origin :v0.2.7      # Delete remote tag
```

## Best Practices

1. **Always test before publishing**
   - Run tests: `yarn test`
   - Type check: `yarn typecheck`
   - Lint: `yarn lint`

2. **Write meaningful commit messages**
   - Describe what changed and why
   - Use conventional commit format when possible

3. **Follow semantic versioning**
   - Patch: Bug fixes
   - Minor: New features (backward compatible)
   - Major: Breaking changes

4. **Keep changelog updated**
   - `yarn release` does this automatically
   - Manually update CHANGELOG.md if not using release-it

5. **Test the published package**
   - Create a test project and install your newly published version
   - Verify all features work as expected

6. **Document breaking changes**
   - Update README.md with migration guides
   - Clearly mark deprecated methods
   - Provide examples of new API usage

## Release Checklist

Before releasing, ensure:

- [ ] All tests pass (`yarn test`)
- [ ] No TypeScript errors (`yarn typecheck`)
- [ ] No linting errors (`yarn lint`)
- [ ] Documentation is updated
- [ ] CHANGELOG is up to date (if manual)
- [ ] README reflects any API changes
- [ ] All changes are committed and pushed
- [ ] Version number is bumped appropriately
- [ ] You have your npm OTP ready

## Getting Help

If you encounter issues:
1. Check this guide's troubleshooting section
2. Review git status and error messages carefully
3. Check npm and GitHub documentation
4. Review `release-it` docs: https://github.com/release-it/release-it

## Configuration Files

Key files involved in the release process:

- `package.json` - Version number and release-it configuration
- `.release-it.json` - Release-it settings (if separate)
- `tsconfig.json` - TypeScript configuration
- `.npmignore` / `package.json:files` - Controls what gets published

---

**Last Updated:** 2025-10-11
**Package:** react-native-auth-client
**Maintainer:** Rahul Unni
