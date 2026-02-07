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
- Pkl runtime (embedded)

### Step 2: Initialize Project

Create a configuration file in your project:

```bash
cd /path/to/your/project
laner init
```

This creates `Laner/Lanerfile.pkl` (your pipeline config) and `Laner/pkl/Lanerfile.pkl` (the schema).

### Step 3: Configure Lanes

Edit `Laner/Lanerfile.pkl` to match your needs:

```pkl
amends "pkl/Lanerfile.pkl"

lanes {
  new {
    name = "build"
    description = "Build the app"
    actions {
      new GymAction {
        scheme = "MyProject"
        configuration = "debug"
      }
    }
  }

  new {
    name = "test"
    description = "Run tests"
    actions {
      new ScanAction {
        scheme = "MyProject"
        codeCoverage = true
      }
    }
  }

  new {
    name = "release"
    description = "Build and archive for release"
    actions {
      new MatchAction {
        certificateType = "appstore"
      }
      new GymAction {
        scheme = "MyProject"
        configuration = "release"
      }
      new ArchiveAction {
        scheme = "MyProject"
        exportMethod = "app-store"
      }
    }
  }
}
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

## Available Actions

| Action                  | Description                             |
| ----------------------- | --------------------------------------- |
| `GymAction`             | Build an iOS/macOS app using xcodebuild |
| `ScanAction`            | Run tests using xcodebuild              |
| `ArchiveAction`         | Archive an app and export an IPA        |
| `MatchAction`           | Sync code signing certificates/profiles |
| `PilotAction`           | Upload a build to TestFlight            |
| `RegisterDevicesAction` | Register devices with Apple Dev Portal  |
| `ShellAction`           | Execute an arbitrary shell command      |

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

```pkl
amends "pkl/Lanerfile.pkl"

local isCI = read?("env:CI") == "true"

lanes {
  // Development build
  new {
    name = "dev"
    description = "Build for development"
    actions {
      new GymAction {
        scheme = "App"
        configuration = "debug"
      }
    }
  }

  // Run tests
  new {
    name = "test"
    description = "Run tests with coverage"
    actions {
      new ScanAction {
        scheme = "App"
        codeCoverage = true
      }
    }
  }

  // Release to TestFlight
  new {
    name = "testflight"
    description = "Build and upload to TestFlight"
    actions {
      new MatchAction {
        certificateType = "appstore"
        readonly = isCI
      }
      new GymAction {
        scheme = "App"
        configuration = "release"
      }
      new ArchiveAction {
        scheme = "App"
        exportMethod = "app-store"
      }
      new PilotAction {
        appId = "123456789"
        changelog = "New features and bug fixes"
        groups {
          "Internal Testers"
        }
      }
    }
  }

  // Beta build with new devices
  new {
    name = "beta"
    description = "Register devices and build beta"
    actions {
      new RegisterDevicesAction {
        file = "devices.txt"
      }
      new MatchAction {
        certificateType = "adhoc"
        forceForNewDevices = true
      }
      new GymAction {
        scheme = "App"
        configuration = "release"
      }
    }
  }

  // Run shell commands
  new {
    name = "lint"
    description = "Run linting"
    actions {
      new ShellAction {
        command = "swiftlint"
        arguments {}
      }
    }
  }
}
```

## Pkl Configuration Features

Pkl is Apple's configuration language that provides:

- **Type safety** - Schema validation catches errors before execution
- **Fast evaluation** - Milliseconds instead of seconds (no compilation)
- **Conditional logic** - Use `read?("env:CI")` for environment-based config
- **No Swift compilation** - Configuration is purely declarative

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

### Pkl Evaluation Errors

1. Check `Laner/Lanerfile.pkl` syntax
2. Ensure `Laner/pkl/Lanerfile.pkl` schema exists
3. Run `laner doctor` to validate the configuration
