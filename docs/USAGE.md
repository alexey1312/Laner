# Laner Usage Guide

Step-by-step instructions for using Laner.

**Other languages:** [Русский](USAGE_RU.md)

## Requirements

- macOS 13.0+
- Swift 6.0+
- Xcode 16.0+ (for iOS/macOS build operations)

## Installation

### Using mise (recommended)

```bash
mise use -g ubi:alexey1312/Laner
```

Or add to `.mise.toml`:

```toml
[tools]
"ubi:alexey1312/Laner" = "latest"
```

### From Source

```bash
git clone https://github.com/alexey1312/Laner.git
cd Laner
swift build -c release
```

The executable will be available at `.build/release/laner`.

### Manual Download

Download from [GitHub Releases](https://github.com/alexey1312/Laner/releases).

## Quick Start

### Step 1: Check Environment

Ensure all required tools are installed:

```bash
laner doctor
```

This checks:

- Swift version
- Git version
- Xcode availability (macOS only)
- xcodebuild availability
- codesign availability

### Step 2: Initialize Project

Create a configuration file in your project:

```bash
cd /path/to/your/project
laner init
```

This creates `Laner/Lanerfile.swift` with an example configuration.

### Step 3: Configure Lanes

Edit `Laner/Lanerfile.swift` to match your needs:

```swift
import LanerDSL

let laner = Lanerfile(
    lanes: [
        Lane("build") {
            gym(scheme: "MyProject", configuration: .debug)
        },
        Lane("test") {
            scan(scheme: "MyProjectTests", codeCoverage: true)
        },
        Lane("release") {
            match(type: .appstore)
            gym(scheme: "MyProject", configuration: .release)
            archive(scheme: "MyProject", exportMethod: .appStore)
        }
    ]
)
```

### Step 4: Run Lanes

```bash
# View available lanes
laner lanes

# Run a specific lane
laner lane build
laner lane test
laner lane release
```

## Core Commands

| Command                   | Description          |
| ------------------------- | -------------------- |
| `laner version`           | Show Laner version   |
| `laner doctor`            | Check environment    |
| `laner init`              | Initialize project   |
| `laner lanes`             | List available lanes |
| `laner lane <name>`       | Execute a lane       |
| `laner build`             | Build project        |
| `laner test`              | Run tests            |
| `laner match sync`        | Sync certificates    |
| `laner upload testflight` | Upload to TestFlight |

## Code Signing Setup (Match)

### Step 1: Set Environment Variables

```bash
export MATCH_PASSWORD="your_encryption_password"
export MATCH_GIT_URL="git@github.com:org/certificates.git"
export MATCH_TEAM_ID="TEAM123"
```

### Step 2: Initialize Match

```bash
laner match init --git-url git@github.com:org/certificates.git --team-id TEAM123
```

### Step 3: Sync Certificates

```bash
# Sync App Store certificates
laner match sync --type appstore

# Sync development certificates
laner match sync --type development
```

### Step 4: Register Devices

```bash
laner match register --devices-file devices.txt
```

## TestFlight Upload

### Step 1: Configure App Store Connect API Keys

```bash
export APP_STORE_CONNECT_API_KEY_ID="D383SF739"
export APP_STORE_CONNECT_API_ISSUER_ID="6053b7fe-68a8-4acb-89be-165aa6465141"
export APP_STORE_CONNECT_API_KEY_PATH="/path/to/AuthKey.p8"
```

### Step 2: Upload IPA

```bash
# Basic upload
laner upload testflight --ipa path/to/app.ipa --app-id 123456789

# With beta group distribution
laner upload testflight --ipa path/to/app.ipa --app-id 123456789 \
    --groups "Internal,External Testers" \
    --changelog "Bug fixes and improvements"
```

## Global Options

All commands support:

```bash
-v, --verbose     # Enable debug-level logging
-q, --quiet       # Suppress all output except errors
-d, --directory   # Run in a different directory
```

## Complete CI/CD Pipeline Example

```swift
import LanerDSL

let laner = Lanerfile(
    lanes: [
        // Development build
        Lane("dev") {
            gym(scheme: "App", configuration: .debug)
        },

        // Run tests
        Lane("test") {
            scan(scheme: "AppTests", codeCoverage: true)
        },

        // Release to TestFlight
        Lane("testflight") {
            match(type: .appstore, readonly: true)
            gym(scheme: "App", exportMethod: .appStore)
            pilot(
                appId: "123456789",
                changelog: "New features and bug fixes",
                groups: ["Internal Testers"]
            )
        },

        // Beta build with new devices
        Lane("beta") {
            registerDevices(file: "devices.txt")
            match(type: .adhoc, forceForNewDevices: true)
            gym(scheme: "App", configuration: .release)
        }
    ]
)
```

## Troubleshooting

### "Command not found" Error

Ensure laner is in your PATH:

```bash
export PATH="$PATH:/path/to/laner"
```

### Code Signing Errors

1. Check MATCH_PASSWORD is set correctly
2. Ensure Git repository access for certificates
3. Run `laner match sync --type development`

### TestFlight Errors

1. Verify App Store Connect API keys
2. Ensure App ID is correct
3. Use `--verbose` for debugging
