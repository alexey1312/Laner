# Project Context

## Purpose

**Laner** — open-source Swift CLI tool for iOS CI/CD, designed as a complete replacement for Fastlane.

Goals:

- Eliminate Ruby dependency
- Accelerate CI pipeline execution
- Provide type-safe configuration via Swift DSL
- Educational project for understanding CI/CD internals
- Cross-platform support: macOS + Linux (API-only operations)

## Tech Stack

- Swift 6.0 (swift-tools-version: 6.0) — default concurrency model
- Swift Package Manager
- swift-argument-parser for CLI
- swift-log for structured logging
- swift-crypto for cross-platform encryption
- async-http-client for HTTP requests
- Yams for YAML parsing

## Project Conventions

### Code Style

- Use Swift 6 default concurrency (no extra flags needed)
- Use `actor` only for types with mutable state needing isolation
- Use `async/await` throughout, avoid callbacks
- Follow Swift API Design Guidelines

### Architecture Patterns

- Modular design with clear dependency graph:
  - `laner` (CLI executable) → `LanerCore`
  - `LanerCore` → `LanerDSL`, `LanerKit`
  - `LanerDSL` → `LanerKit`
  - Plugins → `LanerPluginKit` → `LanerDSL`, `LanerKit`
- Protocol-based abstractions for testability
- Result builders for DSL construction
- Actor-based executors for shell/process management

### Testing Strategy

- Unit tests for all core logic
- Integration tests for CLI commands
- Mock protocols for external dependencies (shell, file system, network)
- Test fixtures for xcodebuild output parsing

### Git Workflow

- Main branch: `main`
- Feature branches: `feature/<change-id>`
- Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`

## Domain Context

- **Lane**: A named sequence of actions (like Fastlane lane)
- **Action**: A single CI/CD operation (build, test, sign, upload)
- **Match**: Code signing management (certificates + provisioning profiles)
- **gym/scan/pilot**: Fastlane-compatible action names for build/test/upload

## Important Constraints

- macOS-only features: xcodebuild, Keychain, Security.framework
- Linux-compatible features: API operations, notifications, metrics
- Must maintain encryption compatibility with Fastlane Match (AES-256-GCM)
- App Store Connect API requires JWT authentication

## External Dependencies

- App Store Connect API (JWT auth)
- Firebase App Distribution API
- Git repositories (for Match certificate storage)
- Slack/Jira webhooks for notifications
