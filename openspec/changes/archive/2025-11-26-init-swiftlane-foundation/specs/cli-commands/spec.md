# CLI Commands Capability

## ADDED Requirements

### Requirement: Build Command
The system SHALL provide a `swiftlane build` command for building iOS projects.

#### Scenario: Build with defaults
- **WHEN** user runs `swiftlane build`
- **THEN** discovers workspace/project in current directory
- **AND** builds with default scheme and debug configuration

#### Scenario: Build with explicit options
- **WHEN** user runs `swiftlane build --workspace App.xcworkspace --scheme App --configuration release`
- **THEN** builds specified workspace/scheme in release mode

#### Scenario: Build for simulator
- **WHEN** user runs `swiftlane build --simulator "iPhone 15"`
- **THEN** builds for specified simulator destination

#### Scenario: Build help
- **WHEN** user runs `swiftlane build --help`
- **THEN** displays all available options with descriptions

### Requirement: Test Command
The system SHALL provide a `swiftlane test` command for running tests.

#### Scenario: Run all tests
- **WHEN** user runs `swiftlane test`
- **THEN** discovers test scheme and runs all tests

#### Scenario: Run with retry
- **WHEN** user runs `swiftlane test --retry-failed`
- **THEN** re-runs failed tests up to 2 times

#### Scenario: Test specific target
- **WHEN** user runs `swiftlane test --only MyTests/testFoo`
- **THEN** runs only specified test

### Requirement: Version Command
The system SHALL provide a `swiftlane version` command.

#### Scenario: Show version
- **WHEN** user runs `swiftlane version`
- **THEN** displays Swiftlane version, Swift version, and OS

### Requirement: Doctor Command
The system SHALL provide a `swiftlane doctor` command for environment diagnostics.

#### Scenario: Check environment
- **WHEN** user runs `swiftlane doctor`
- **THEN** checks for:
  - Xcode installation and version
  - Swift version
  - Required tools (git, xcodebuild)
  - Environment configuration

#### Scenario: Missing Xcode
- **WHEN** Xcode is not installed
- **THEN** reports error with installation instructions

### Requirement: Global Options
The system SHALL support global options applicable to all commands.

#### Scenario: Verbose output
- **WHEN** user runs `swiftlane --verbose build`
- **THEN** enables debug-level logging

#### Scenario: Quiet mode
- **WHEN** user runs `swiftlane --quiet build`
- **THEN** suppresses all output except errors

#### Scenario: Working directory
- **WHEN** user runs `swiftlane --directory /path/to/project build`
- **THEN** executes in specified directory

### Requirement: Exit Codes
The system SHALL use meaningful exit codes.

#### Scenario: Success
- **WHEN** command completes successfully
- **THEN** exits with code 0

#### Scenario: Build failure
- **WHEN** build fails
- **THEN** exits with code 1

#### Scenario: Invalid arguments
- **WHEN** invalid arguments provided
- **THEN** exits with code 64 (EX_USAGE)

### Requirement: Error Formatting
The system SHALL format errors for CLI readability.

#### Scenario: Build error display
- **WHEN** build fails with compiler errors
- **THEN** displays formatted error messages with file:line references
- **AND** uses colors when terminal supports them
