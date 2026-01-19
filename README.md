# Laner

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Falexey1312%2FLaner%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/alexey1312/Laner)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Falexey1312%2FLaner%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/alexey1312/Laner)
[![CI](https://github.com/alexey1312/Laner/actions/workflows/ci.yml/badge.svg)](https://github.com/alexey1312/Laner/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/release/alexey1312/Laner.svg)](https://github.com/alexey1312/Laner/releases/latest)
[![License](https://img.shields.io/github/license/alexey1312/Laner.svg)](LICENSE.md)

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

```bash
# Check environment
laner doctor

# Initialize Laner in your project
laner init

# List available lanes
laner lanes

# Execute a lane
laner lane build
```

## Commands

| Command             | Description                                    |
| ------------------- | ---------------------------------------------- |
| `version`           | Show Laner version and environment             |
| `doctor`            | Check environment for required tools           |
| `init`              | Initialize a new Laner project                 |
| `lanes`             | List available lanes from manifest             |
| `lane <name>`       | Execute a lane by name                         |
| `build`             | Build an iOS or macOS project                  |
| `test`              | Run tests for an iOS or macOS project          |
| `match`             | Code signing management (sync, nuke, register) |
| `upload testflight` | Upload IPA to TestFlight                       |

## DSL Example

```swift
// Laner/Lanerfile.swift
import LanerDSL

let laner = Lanerfile(
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
        Lane("testflight") {
            match(type: .appstore, readonly: true)
            gym(scheme: "App", exportMethod: .appStore)
            pilot(
                appId: "123456789",
                changelog: "Bug fixes and improvements",
                groups: ["Internal Testers"]
            )
        }
    ]
)
```

## Module Structure

- **laner** - CLI executable
- **LanerCore** - Internal implementation (commands, orchestration)
- **LanerDSL** - Public DSL API for defining lanes and actions
- **LanerKit** - Shared utilities (shell execution, logging, xcodebuild)
- **LanerPluginKit** - Plugin development kit
- **LanerMatch** - Code signing management (Match-compatible)

## Environment Variables

| Variable                          | Description                                 |
| --------------------------------- | ------------------------------------------- |
| `MATCH_PASSWORD`                  | Encryption password for certificates        |
| `MATCH_GIT_URL`                   | Git repository URL for certificate storage  |
| `MATCH_TEAM_ID`                   | Apple Developer Team ID                     |
| `APP_STORE_APP_ID`                | App Store Connect App ID (for pilot action) |
| `APP_STORE_CONNECT_API_KEY_ID`    | App Store Connect API Key ID                |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect Issuer ID                 |
| `APP_STORE_CONNECT_API_KEY_PATH`  | Path to .p8 private key file                |

## Documentation

| Document                                               | Description                                         |
| ------------------------------------------------------ | --------------------------------------------------- |
| [Usage Guide](docs/USAGE.md)                           | Step-by-step usage instructions                     |
| [Инструкция (RU)](docs/USAGE_RU.md)                    | Пошаговая инструкция на русском                     |
| [Actions Reference](docs/ACTIONS.md)                   | Available DSL actions and custom action development |
| [Environment Variables](docs/ENVIRONMENT_VARIABLES.md) | Complete environment variable reference             |
| [Implementation Plan](docs/IMPLEMENTATION_PLAN.md)     | Architecture and development roadmap                |
| [Fastlane Analysis](docs/FASTLANE_ANALYSIS.md)         | Comparison with Fastlane                            |

## Development

```bash
# Build
swift build

# Run tests
swift test

# Run the CLI
swift run laner --help

# Build for release
swift build -c release
```

## Roadmap

### Implemented

- [x] CLI with ArgumentParser (`build`, `test`, `doctor`, `version`, `init`, `lanes`, `lane`, `match`, `upload`)
- [x] ShellExecutor — async process runner
- [x] XcodebuildExecutor — build/test/archive wrapper
- [x] Structured logging with color support
- [x] CI environment detection
- [x] Lane and Action protocols
- [x] Lane execution from Swift manifests — `laner lane <name>`
- [x] LaneBuilder result builder for declarative DSL
- [x] Built-in actions: `gym()`, `scan()`, `archive()`, `match()`, `registerDevices()`, `pilot()`
- [x] Manifest compilation and caching
- [x] Code Signing (Match) — git-based certificate management, Fastlane Match compatible
- [x] TestFlight Upload — chunked IPA upload via Build Upload API v4.1+, beta group distribution

### Planned

- [ ] App Store Connect (Full) — App Store submission (`deliver()`), metadata, screenshots, phased release
- [ ] Firebase App Distribution — upload and tester management
- [ ] Notifications — Slack, Jira integrations
- [ ] Metrics — build time tracking, IPA size monitoring
- [ ] Plugin system — extensible architecture

## License

MIT License - see LICENSE file for details.
