# Tasks: Initialize Swiftlane Foundation

## 1. Project Setup
- [x] 1.1 Create Package.swift with swift-tools-version: 6.0
- [x] 1.2 Configure module structure (swiftlane, SwiftlaneCore, SwiftlaneDSL, SwiftlaneKit, SwiftlanePluginKit)
- [x] 1.3 Add dependencies (swift-argument-parser, swift-log)
- [x] 1.4 Create .gitignore, LICENSE, README.md
- [x] 1.5 Create GitHub Actions CI workflow (.github/workflows/ci.yml)
- [x] 1.6 Verify `swift build` succeeds with empty targets

## 2. SwiftlaneKit (Shared Utilities)
- [x] 2.1 Create `ProcessResult` struct
- [x] 2.2 Create `ShellError` enum with cases (commandNotFound, timeout, executionFailed)
- [x] 2.3 Create `FileManager+Extensions` for common operations
- [x] 2.4 Create platform detection helpers (`#if os(macOS)` wrappers)
- [x] 2.5 Write unit tests for utilities

## 3. Shell Executor
- [x] 3.1 Create `ShellExecutor` actor with `run()` method
- [x] 3.2 Implement `stream()` method returning `AsyncThrowingStream<String, Error>`
- [x] 3.3 Add working directory support
- [x] 3.4 Add environment variables support
- [x] 3.5 Add timeout support with process termination
- [x] 3.6 Write unit tests with mock processes
- [x] 3.7 Write integration tests with real commands (echo, pwd)

## 4. Logging
- [x] 4.1 Create `LogCategory` enum (shell, xcodebuild, cli, dsl, config)
- [x] 4.2 Create `Logger.swiftlane(_:)` factory method
- [x] 4.3 Create `ConsoleLogHandler` with color support
- [x] 4.4 Implement CI detection for output formatting
- [x] 4.5 Add `--verbose` and `--quiet` support infrastructure
- [x] 4.6 Write tests for log formatting

## 5. Xcodebuild Executor (macOS only)
- [x] 5.1 Create `BuildOptions` struct
- [x] 5.2 Create `TestOptions` struct
- [x] 5.3 Create `ArchiveOptions` struct
- [x] 5.4 Create `XcodebuildExecutor` struct
- [x] 5.5 Implement `build(options:)` method
- [x] 5.6 Implement `test(options:)` method
- [x] 5.7 Implement `archive(options:)` method
- [x] 5.8 Implement `exportArchive(options:)` method
- [x] 5.9 Create `BuildResult`, `TestResult`, `ArchiveResult` structs
- [x] 5.10 Add xcodebuild output parsing for errors
- [x] 5.11 Write unit tests with fixture output
- [x] 5.12 Write integration test with real xcodebuild (optional, CI-only)

## 6. DSL Core
- [x] 6.1 Create `Action` protocol
- [x] 6.2 Create `AnyAction` type-erased wrapper
- [x] 6.3 Create `Lane` struct with name, description, actions
- [x] 6.4 Create `ExecutionContext` actor
- [x] 6.5 Create `Environment` struct with CI detection
- [x] 6.6 Create `Artifact` and `ArtifactStore` types
- [x] 6.7 Create `SwiftlaneConfiguration` protocol
- [x] 6.8 Implement basic lane execution logic
- [x] 6.9 Write tests for lane execution

## 7. CLI Commands
- [x] 7.1 Create main entry point with ArgumentParser
- [x] 7.2 Create `SwiftlaneCommand` root command with global options
- [x] 7.3 Implement `VersionCommand`
- [x] 7.4 Implement `DoctorCommand` with environment checks
- [x] 7.5 Implement `BuildCommand` with xcodebuild integration
- [x] 7.6 Implement `TestCommand` with xcodebuild integration
- [x] 7.7 Add exit code handling
- [x] 7.8 Add error formatting
- [x] 7.9 Write tests for argument parsing
- [x] 7.10 Write integration tests for commands

## 8. Integration & Polish
- [x] 8.1 End-to-end test: `swiftlane build` on sample project (manual verification)
- [x] 8.2 End-to-end test: `swiftlane test` on sample project (manual verification)
- [x] 8.3 Verify Swift 6 builds without warnings
- [x] 8.4 Update README with usage instructions
- [x] 8.5 Create Examples/BasicSwiftlanefile.swift

## Dependencies
- Tasks 2.x must complete before 3.x (ShellExecutor depends on Kit)
- Tasks 3.x must complete before 5.x (XcodebuildExecutor uses ShellExecutor)
- Tasks 4.x can run in parallel with 3.x
- Tasks 6.x depend on 3.x and 4.x
- Tasks 7.x depend on 5.x and 6.x
- Tasks 8.x require all previous tasks

## Verification
After all tasks complete:
- [x] `swift build` succeeds on macOS
- [x] `swift build` succeeds on Linux (with platform stubs)
- [x] `swift test` passes all tests
- [x] `swiftlane version` shows correct version
- [x] `swiftlane doctor` reports environment status
- [x] `swiftlane build --help` shows all options
