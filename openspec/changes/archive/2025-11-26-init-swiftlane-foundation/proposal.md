# Change: Initialize Laner Foundation

## Why

Laner needs a solid foundation to build upon. This proposal establishes the core infrastructure: Swift Package structure, shell execution layer, xcodebuild integration, CLI commands, DSL basics, and logging. This is Phase 1 from IMPLEMENTATION_PLAN.md, using Swift 6 (swift-tools-version: 6.0).

## What Changes

- **NEW** Swift Package with modular architecture (laner, LanerCore, LanerDSL, LanerKit, LanerPluginKit)
- **NEW** `ShellExecutor` actor for async process execution with streaming output
- **NEW** `XcodebuildExecutor` for build/test/archive operations
- **NEW** CLI commands: `build`, `test`, `version`, `doctor`
- **NEW** Basic DSL infrastructure with `Lane` and `Action` protocols
- **NEW** Structured logging with swift-log
- **NEW** GitHub Actions CI workflow with Swift 6.0/6.1/6.2 matrix

**Technical decisions:**

- Swift 6 (swift-tools-version: 6.0) — default concurrency model, no extra flags
- Actor-based executors where state isolation is needed
- Platform-conditional compilation for macOS/Linux

## Impact

- Affected specs: NEW capabilities (shell-executor, xcodebuild-executor, cli-commands, dsl-core, logging, ci-workflow)
- Affected code: Creates entire project structure from scratch
- Dependencies: swift-argument-parser 1.3+, swift-log 1.5+

## Scope

This is the foundation (Phase 1). Future phases will add:

- Phase 2: Full DSL with result builders
- Phase 3: Match (code signing)
- Phase 4: App Store Connect
- Phase 5: Firebase
- Phase 6: Notifications
- Phase 7: Metrics
- Phase 8: Documentation
