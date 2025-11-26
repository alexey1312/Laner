# LanerMatch Environment Variables

This document lists all environment variables recognized by LanerMatch for configuring code signing with Match.

## Overview

LanerMatch can be configured using environment variables, making it ideal for CI/CD environments. All configuration can be provided through `MatchConfiguration.fromEnvironment()` or by directly passing values to the `match()` DSL function.

## Required Variables

### MATCH_PASSWORD

**Description:** Password used to encrypt and decrypt certificates and provisioning profiles in the Git repository.

**Type:** String

**Required:** Yes

**Security:** This password should be kept secure and never committed to version control. Store it in your CI/CD secrets manager.

**Example:**
```bash
export MATCH_PASSWORD="my_secure_password_123"
```

**Notes:**
- Use a strong, randomly generated password
- Same password must be used by all team members
- Store securely in CI secrets (GitHub Secrets, GitLab CI Variables, etc.)
- Password is used for AES-256-GCM encryption with HKDF-SHA256 key derivation

---

### MATCH_GIT_URL

**Description:** URL of the Git repository where encrypted certificates and provisioning profiles are stored.

**Type:** String (URL)

**Required:** Yes

**Format:** Any valid Git URL (HTTPS or SSH)

**Example:**
```bash
export MATCH_GIT_URL="https://github.com/mycompany/ios-certificates.git"
export MATCH_GIT_URL="git@github.com:mycompany/ios-certificates.git"
export MATCH_GIT_URL="https://gitlab.com/mycompany/ios-certificates.git"
```

**Notes:**
- Repository can be private (recommended)
- Must have read access for CI builds
- Must have write access for certificate creation/update
- Can use different repositories for different teams/projects

---

## Optional Variables

### MATCH_GIT_BRANCH

**Description:** Git branch to use for certificate storage.

**Type:** String

**Required:** No

**Default:** `"master"`

**Example:**
```bash
export MATCH_GIT_BRANCH="main"
export MATCH_GIT_BRANCH="develop"
export MATCH_GIT_BRANCH="staging"
```

**Use Cases:**
- Use different branches for different environments (dev, staging, production)
- Separate certificate management for different teams
- Maintain multiple certificate sets within one repository

---

### MATCH_TEAM_ID

**Description:** Apple Developer Team ID (10-character alphanumeric identifier).

**Type:** String

**Required:** No (but recommended)

**Format:** 10-character alphanumeric string

**Example:**
```bash
export MATCH_TEAM_ID="ABC123DEF4"
```

**How to Find:**
1. Log in to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to Membership section
3. Find "Team ID" in the membership details

**Notes:**
- Required for certificate operations via App Store Connect API
- Used to filter certificates and profiles for your team
- Same team ID is used across all your iOS/macOS apps

---

### MATCH_READONLY

**Description:** When set to "true", prevents Match from creating new certificates or provisioning profiles.

**Type:** Boolean (string "true" or "false")

**Required:** No

**Default:** `false`

**Example:**
```bash
export MATCH_READONLY="true"   # CI builds (don't create new certificates)
export MATCH_READONLY="false"  # Local development (can create certificates)
```

**Use Cases:**
- **CI/CD environments:** Set to `true` to ensure builds only use existing certificates
- **Production pipelines:** Prevent accidental certificate creation
- **Readonly access:** When team members should only consume certificates, not create them

**Behavior:**
- When `true`: Throws error if certificates/profiles don't exist
- When `false`: Creates new certificates/profiles if needed (requires App Store Connect API credentials)

---

### MATCH_FORCE_FOR_NEW_DEVICES

**Description:** Force regeneration of provisioning profiles when new devices are registered.

**Type:** Boolean (string "true" or "false")

**Required:** No

**Default:** `false`

**Example:**
```bash
export MATCH_FORCE_FOR_NEW_DEVICES="true"
```

**Use Cases:**
- After registering new test devices
- When adding devices to ad-hoc or development profiles
- Ensures newly registered devices are included in provisioning profiles

**Behavior:**
- When `true`: Regenerates provisioning profiles to include newly registered devices
- When `false`: Uses existing provisioning profiles without modification

**Note:** Only applies to development and ad-hoc profiles (not App Store or enterprise)

---

### MATCH_GIT_BASIC_AUTHORIZATION

**Description:** Base64-encoded basic authentication credentials for Git access.

**Type:** String (Base64 encoded)

**Required:** No (only needed for private repositories with basic auth)

**Format:** Base64 encoded "username:password" or "username:token"

**Example:**
```bash
# Encode credentials
echo -n "username:password" | base64
# Result: dXNlcm5hbWU6cGFzc3dvcmQ=

export MATCH_GIT_BASIC_AUTHORIZATION="dXNlcm5hbWU6cGFzc3dvcmQ="
```

**Use Cases:**
- Private Git repositories requiring authentication
- CI environments without SSH key access
- Using personal access tokens instead of passwords

**Alternatives:**
- SSH keys (preferred for production)
- Deploy keys (for CI/CD)
- OAuth tokens (for GitHub, GitLab)

**Security:**
- Store encoded value in CI secrets
- Use personal access tokens instead of passwords
- Limit token scope to repository access only

---

## App Store Connect API Variables

These variables are required for operations that interact with App Store Connect (creating certificates, registering devices, managing profiles).

### APP_STORE_CONNECT_API_KEY_ID

**Description:** App Store Connect API Key identifier.

**Type:** String

**Required:** No (required for API operations: certificate creation, device registration, profile management)

**Format:** 10-character alphanumeric string (e.g., "ABC123XYZ9")

**Example:**
```bash
export APP_STORE_CONNECT_API_KEY_ID="ABC123XYZ9"
```

**How to Create:**
1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to Users and Access > Keys
3. Click "+" to generate new API key
4. Choose appropriate access level (Admin or Developer)
5. Download the private key (.p8 file)
6. Note the Key ID

**Notes:**
- Required together with `APP_STORE_CONNECT_API_ISSUER_ID` and `APP_STORE_CONNECT_API_KEY_PATH`
- Key ID is visible in App Store Connect
- Cannot be changed after key creation

---

### APP_STORE_CONNECT_API_ISSUER_ID

**Description:** App Store Connect API Issuer ID (UUID format).

**Type:** String (UUID)

**Required:** No (required for API operations)

**Format:** UUID string (8-4-4-4-12 format)

**Example:**
```bash
export APP_STORE_CONNECT_API_ISSUER_ID="12345678-1234-1234-1234-123456789012"
```

**How to Find:**
1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to Users and Access > Keys
3. Find "Issuer ID" at the top of the page

**Notes:**
- Same for all API keys in your organization
- UUID format identifier
- Required together with Key ID and private key

---

### APP_STORE_CONNECT_API_KEY_PATH

**Description:** File path to the App Store Connect API private key (.p8 file).

**Type:** String (file path)

**Required:** No (required for API operations)

**Format:** Absolute or relative path to .p8 file

**Example:**
```bash
export APP_STORE_CONNECT_API_KEY_PATH="/path/to/AuthKey_ABC123XYZ9.p8"
export APP_STORE_CONNECT_API_KEY_PATH="./AuthKey.p8"
export APP_STORE_CONNECT_API_KEY_PATH="${HOME}/.appstoreconnect/AuthKey.p8"
```

**File Format:**
The .p8 file is a PEM-encoded PKCS#8 private key:
```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
-----END PRIVATE KEY-----
```

**Security:**
- Never commit .p8 files to version control
- Store securely (CI secrets, credential managers)
- Restrict file permissions (e.g., `chmod 600 AuthKey.p8`)
- Can only download once from App Store Connect

**CI Setup:**
```bash
# Store key content in CI secret as base64
echo "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 -d > AuthKey.p8
chmod 600 AuthKey.p8
export APP_STORE_CONNECT_API_KEY_PATH="./AuthKey.p8"
```

---

## Configuration Priority

When both environment variables and explicit parameters are provided to `match()`, the priority is:

1. **Explicit parameters** in the `match()` function call (highest priority)
2. **Environment variables**
3. **Default values** (lowest priority)

**Example:**
```swift
// This uses the explicit gitUrl, overriding MATCH_GIT_URL
match(
    type: .development,
    appIdentifier: "com.example.app",
    gitUrl: "https://github.com/specific/repo.git"  // Overrides MATCH_GIT_URL
)
```

---

## Complete Configuration Examples

### Local Development

```bash
# .env.local
export MATCH_PASSWORD="local_dev_password"
export MATCH_GIT_URL="https://github.com/mycompany/certificates.git"
export MATCH_GIT_BRANCH="develop"
export MATCH_TEAM_ID="ABC123DEF4"
export MATCH_READONLY="false"
export APP_STORE_CONNECT_API_KEY_ID="XYZ987ABC6"
export APP_STORE_CONNECT_API_ISSUER_ID="12345678-1234-1234-1234-123456789012"
export APP_STORE_CONNECT_API_KEY_PATH="${HOME}/.appstoreconnect/AuthKey.p8"
```

### CI/CD Environment (GitHub Actions)

```yaml
name: iOS CI

on: [push]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup App Store Connect API Key
        run: |
          echo "${{ secrets.APP_STORE_CONNECT_API_KEY }}" | base64 -d > AuthKey.p8
          chmod 600 AuthKey.p8

      - name: Build with Match
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_URL: https://github.com/mycompany/certificates.git
          MATCH_GIT_BRANCH: main
          MATCH_TEAM_ID: ABC123DEF4
          MATCH_READONLY: true
          APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          APP_STORE_CONNECT_API_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_PATH: ./AuthKey.p8
        run: |
          laner lane appstore
```

### CI/CD Environment (GitLab CI)

```yaml
variables:
  MATCH_GIT_URL: "https://gitlab.com/mycompany/certificates.git"
  MATCH_GIT_BRANCH: "main"
  MATCH_TEAM_ID: "ABC123DEF4"
  MATCH_READONLY: "true"

ios_build:
  stage: build
  script:
    - echo $APP_STORE_CONNECT_API_KEY | base64 -d > AuthKey.p8
    - chmod 600 AuthKey.p8
    - export APP_STORE_CONNECT_API_KEY_PATH="./AuthKey.p8"
    - laner lane appstore
  variables:
    MATCH_PASSWORD: $MATCH_PASSWORD_SECRET
    APP_STORE_CONNECT_API_KEY_ID: $ASC_KEY_ID
    APP_STORE_CONNECT_API_ISSUER_ID: $ASC_ISSUER_ID
```

### CI/CD Environment (Jenkins)

```groovy
pipeline {
    agent { label 'macos' }

    environment {
        MATCH_PASSWORD = credentials('match-password')
        MATCH_GIT_URL = 'https://github.com/mycompany/certificates.git'
        MATCH_GIT_BRANCH = 'main'
        MATCH_TEAM_ID = 'ABC123DEF4'
        MATCH_READONLY = 'true'
        APP_STORE_CONNECT_API_KEY_ID = credentials('asc-key-id')
        APP_STORE_CONNECT_API_ISSUER_ID = credentials('asc-issuer-id')
        APP_STORE_CONNECT_API_KEY_PATH = './AuthKey.p8'
    }

    stages {
        stage('Setup') {
            steps {
                sh '''
                    echo "$APP_STORE_CONNECT_API_KEY" | base64 -d > AuthKey.p8
                    chmod 600 AuthKey.p8
                '''
            }
        }

        stage('Build') {
            steps {
                sh 'laner lane appstore'
            }
        }
    }
}
```

### Docker Environment

```dockerfile
# Dockerfile
FROM swift:latest

# Install dependencies
RUN apt-get update && apt-get install -y git

# Set working directory
WORKDIR /workspace

# Copy project
COPY . .

# Build
RUN swift build

# Set environment variables at runtime
ENV MATCH_PASSWORD=""
ENV MATCH_GIT_URL=""
ENV MATCH_GIT_BRANCH="main"
ENV MATCH_TEAM_ID=""
ENV MATCH_READONLY="true"

CMD ["laner", "lane", "appstore"]
```

```bash
# Run with environment variables
docker run \
  -e MATCH_PASSWORD="$MATCH_PASSWORD" \
  -e MATCH_GIT_URL="https://github.com/mycompany/certificates.git" \
  -e MATCH_TEAM_ID="ABC123DEF4" \
  -e APP_STORE_CONNECT_API_KEY_ID="$ASC_KEY_ID" \
  -e APP_STORE_CONNECT_API_ISSUER_ID="$ASC_ISSUER_ID" \
  -v "$PWD/AuthKey.p8:/workspace/AuthKey.p8" \
  -e APP_STORE_CONNECT_API_KEY_PATH="/workspace/AuthKey.p8" \
  myapp-builder
```

---

## Security Best Practices

### Secrets Management

```toon
best_practices[8]{practice,description}:
  Never commit secrets,Store all passwords and keys outside version control
  Use CI secrets,Leverage built-in secrets management in CI platforms
  Rotate credentials,Regularly rotate passwords and API keys
  Limit access,Restrict who can view/modify secrets
  Use temporary credentials,Consider short-lived tokens where possible
  Encrypt at rest,Ensure CI platform encrypts secrets at rest
  Audit access,Monitor who accesses sensitive credentials
  Separate environments,Use different credentials for dev/staging/prod
```

### API Key Permissions

When creating App Store Connect API keys:

- **Admin Role:** Full access (certificate creation, device registration, profile management)
- **Developer Role:** Limited access (may not have all permissions)
- **Choose minimum required role** for your use case

### Git Repository Security

```toon
security_measures[6]{measure,implementation}:
  Private repository,Use private Git repository for certificates
  Access control,Limit who can push to certificate repository
  Branch protection,Enable branch protection on main certificate branches
  Audit logs,Enable audit logging for repository access
  SSH keys,Prefer SSH keys over HTTPS passwords
  Deploy keys,Use read-only deploy keys for CI
```

---

## Troubleshooting

### Common Issues

**Issue:** `Missing environment variable: MATCH_PASSWORD`
- **Solution:** Set `MATCH_PASSWORD` environment variable

**Issue:** `Git clone failed: authentication failed`
- **Solution:** Check Git credentials, ensure repository access, verify `MATCH_GIT_URL`

**Issue:** `Invalid password - decryption failed`
- **Solution:** Verify `MATCH_PASSWORD` matches the password used to encrypt certificates

**Issue:** `App Store Connect API authentication failed`
- **Solution:** Verify all three API variables are set correctly (Key ID, Issuer ID, Key Path)

**Issue:** `File not found: /path/to/AuthKey.p8`
- **Solution:** Verify `APP_STORE_CONNECT_API_KEY_PATH` points to valid .p8 file

**Issue:** `Cannot create certificates in readonly mode`
- **Solution:** Set `MATCH_READONLY="false"` or create certificates manually first

### Debugging Environment Variables

```bash
# Check which variables are set
env | grep MATCH_
env | grep APP_STORE_CONNECT_

# Verify values (be careful not to expose secrets)
echo "MATCH_GIT_URL: $MATCH_GIT_URL"
echo "MATCH_GIT_BRANCH: $MATCH_GIT_BRANCH"
echo "MATCH_READONLY: $MATCH_READONLY"

# Test configuration
laner doctor  # Check environment setup
```

---

## See Also

- [Match Configuration Examples](../../Examples/MatchConfig.swift)
- [LanerMatch API Documentation](./LanerMatch.swift)
- [CryptoService Documentation](./Services/CryptoService.swift)
- [App Store Connect API Setup Guide](https://developer.apple.com/documentation/appstoreconnectapi)
