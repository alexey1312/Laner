# Swiftlane

[![CI](https://github.com/alexey1312/Swiftlane/actions/workflows/ci.yml/badge.svg)](https://github.com/alexey1312/Swiftlane/actions/workflows/ci.yml)

A Swift-native CI/CD automation tool for iOS and macOS projects.

## Features

- **Build & Test**: Build and test iOS/macOS projects with xcodebuild
- **Code Signing (Match)**: Git-based certificate and profile management, Fastlane Match compatible
- **TestFlight Upload**: Upload builds to TestFlight with chunked uploads and beta distribution
- **Environment Detection**: Automatic CI detection (GitHub Actions, GitLab CI, Jenkins, etc.)
- **Lane DSL**: Define CI/CD workflows using Swift
- **Type-Safe Actions**: Build custom actions with full Swift type safety
- **Structured Logging**: Configurable logging with color support
- **Async/Await**: Modern Swift 6 concurrency throughout

## Requirements

- macOS 13.0+
- Swift 6.0+
- Xcode 16.0+ (for iOS/macOS build operations)

## Installation

### Using mise (recommended)

```bash
mise use -g ubi:alexey1312/Swiftlane
```

Or add to `.mise.toml`:

```toml
[tools]
"ubi:alexey1312/Swiftlane" = "latest"
```

### From Source

```bash
git clone https://github.com/alexey1312/Swiftlane.git
cd Swiftlane
swift build -c release
```

The executable will be available at `.build/release/swiftlane`.

### Manual Download

Download from [GitHub Releases](https://github.com/alexey1312/Swiftlane/releases).

## Quick Start

### Check Environment

```bash
swiftlane doctor
```

### Build a Project

```bash
# Auto-discover workspace/project in current directory
swiftlane build

# Specify workspace and scheme
swiftlane build --workspace App.xcworkspace --scheme App

# Build for release
swiftlane build --configuration Release

# Build for simulator
swiftlane build --simulator "iPhone 15"

# Clean build
swiftlane build --clean
```

### Run Tests

```bash
# Run all tests
swiftlane test

# Specify simulator
swiftlane test --simulator "iPhone 15"

# Run specific test
swiftlane test --only "MyTests/testExample"
```

### Use Lanes (Recommended)

```bash
# Initialize Swiftlane in your project
swiftlane init

# List available lanes
swiftlane lanes

# Execute a lane
swiftlane lane build
swiftlane lane test
swiftlane lane release
```

### Global Options

All commands support these global options:

```bash
-v, --verbose     Enable debug-level logging
-q, --quiet       Suppress all output except errors
-d, --directory   Run in a different directory
```

## Commands

| Command         | Description                              |
|-----------------|------------------------------------------|
| `version`       | Show Swiftlane version and environment   |
| `doctor`        | Check environment for required tools     |
| `init`          | Initialize a new Swiftlane project       |
| `lanes`         | List available lanes from manifest       |
| `lane <name>`   | Execute a lane by name                   |
| `build`         | Build an iOS or macOS project            |
| `test`          | Run tests for an iOS or macOS project    |
| `match`         | Code signing management (sync, nuke, register) |
| `upload testflight` | Upload IPA to TestFlight               |

## Module Structure

- **swiftlane** - CLI executable
- **SwiftlaneCore** - Internal implementation (commands, orchestration)
- **SwiftlaneDSL** - Public DSL API for defining lanes and actions
- **SwiftlaneKit** - Shared utilities (shell execution, logging, xcodebuild)
- **SwiftlanePluginKit** - Plugin development kit
- **SwiftlaneMatch** - Code signing management (Match-compatible)

## Development

```bash
# Build
swift build

# Run tests
swift test

# Run the CLI
swift run swiftlane --help

# Build for release
swift build -c release
```

## DSL Example

```swift
// Swiftlane/Swiftlanefile.swift
import SwiftlaneDSL

let swiftlane = Swiftlanefile(
    lanes: [
        Lane("build") {
            gym(scheme: "App", configuration: .debug)
        },
        Lane("test") {
            scan(scheme: "AppTests", codeCoverage: true)
        },
        Lane("release") {
            match(type: .appstore)
            gym(scheme: "App", configuration: .release)
            archive(scheme: "App", exportMethod: .appStore)
        },
        Lane("beta") {
            registerDevices(file: "devices.txt")
            match(type: .adhoc, forceForNewDevices: true)
            gym(scheme: "App", configuration: .release)
        },
        Lane("testflight") {
            match(type: .appstore, readonly: true)
            gym(scheme: "App", exportMethod: .appStore)
            pilot(
                appId: "123456789",
                changelog: "Bug fixes and improvements",
                groups: ["Internal Testers", "External Testers"]
            )
        }
    ]
)
```

## Code Signing (Match)

Swiftlane includes a Fastlane Match-compatible code signing solution:

```bash
# Sync certificates and profiles
swiftlane match sync --type appstore

# Register new devices
swiftlane match register --devices-file devices.txt

# Initialize Match configuration
swiftlane match init --git-url git@github.com:org/certificates.git --team-id TEAM123
```

## TestFlight Upload

Upload builds to TestFlight with chunked uploads and automatic beta distribution:

```bash
# Upload IPA to TestFlight
swiftlane upload testflight --ipa path/to/app.ipa --app-id 123456789

# Upload with beta group distribution
swiftlane upload testflight --ipa path/to/app.ipa --app-id 123456789 \
    --groups "Internal,External Testers" \
    --changelog "Bug fixes and improvements"

# Skip waiting for processing
swiftlane upload testflight --ipa path/to/app.ipa --app-id 123456789 --skip-waiting
```

Or use the `pilot()` DSL action in your lanes:

```swift
Lane("testflight") {
    match(type: .appstore, readonly: true)
    gym(scheme: "App", exportMethod: .appStore)
    pilot(
        appId: "123456789",
        changelog: "Bug fixes and improvements",
        groups: ["Internal Testers"]
    )
}
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `MATCH_PASSWORD` | Encryption password for certificates |
| `MATCH_GIT_URL` | Git repository URL for certificate storage |
| `MATCH_TEAM_ID` | Apple Developer Team ID |
| `APP_STORE_APP_ID` | App Store Connect App ID (for pilot action) |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect Issuer ID |
| `APP_STORE_CONNECT_API_KEY_PATH` | Path to .p8 private key file |

## Roadmap

### Implemented

- [x] CLI with ArgumentParser (`build`, `test`, `doctor`, `version`, `init`, `lanes`, `lane`, `match`, `upload`)
- [x] ShellExecutor — async process runner
- [x] XcodebuildExecutor — build/test/archive wrapper
- [x] Structured logging with color support
- [x] CI environment detection
- [x] Lane and Action protocols
- [x] **Lane execution from Swift manifests** — `swiftlane lane <name>`
- [x] LaneBuilder result builder for declarative DSL
- [x] Built-in actions: `gym()`, `scan()`, `archive()`, `match()`, `registerDevices()`, `pilot()`
- [x] Manifest compilation and caching
- [x] **Code Signing (Match)** — git-based certificate management, Fastlane Match compatible
- [x] **TestFlight Upload** — chunked IPA upload via Build Upload API v4.1+, beta group distribution

### Planned

- [ ] **App Store Connect (Full)** — App Store submission (`deliver()`), metadata, screenshots, phased release
- [ ] **Firebase App Distribution** — upload and tester management
- [ ] **Notifications** — Slack, Jira integrations
- [ ] **Metrics** — build time tracking, IPA size monitoring
- [ ] **Plugin system** — extensible architecture

## License

MIT License - see LICENSE file for details.
