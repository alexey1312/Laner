# CLI Commands Capability

## ADDED Requirements

### Requirement: Build Command
The system SHALL provide a `laner build` command for building iOS projects.

#### Scenario: Build with defaults
- **WHEN** user runs `laner build`
- **THEN** discovers workspace/project in current directory
- **AND** builds with default scheme and debug configuration

#### Scenario: Build with explicit options
- **WHEN** user runs `laner build --workspace App.xcworkspace --scheme App --configuration release`
- **THEN** builds specified workspace/scheme in release mode

#### Scenario: Build for simulator
- **WHEN** user runs `laner build --simulator "iPhone 15"`
- **THEN** builds for specified simulator destination

#### Scenario: Build help
- **WHEN** user runs `laner build --help`
- **THEN** displays all available options with descriptions

### Requirement: Test Command
The system SHALL provide a `laner test` command for running tests.

#### Scenario: Run all tests
- **WHEN** user runs `laner test`
- **THEN** discovers test scheme and runs all tests

#### Scenario: Run with retry
- **WHEN** user runs `laner test --retry-failed`
- **THEN** re-runs failed tests up to 2 times

#### Scenario: Test specific target
- **WHEN** user runs `laner test --only MyTests/testFoo`
- **THEN** runs only specified test

### Requirement: Version Command
The system SHALL provide a `laner version` command.

#### Scenario: Show version
- **WHEN** user runs `laner version`
- **THEN** displays Laner version, Swift version, and OS

### Requirement: Doctor Command
The system SHALL provide a `laner doctor` command for environment diagnostics.

#### Scenario: Check environment
- **WHEN** user runs `laner doctor`
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
- **WHEN** user runs `laner --verbose build`
- **THEN** enables debug-level logging

#### Scenario: Quiet mode
- **WHEN** user runs `laner --quiet build`
- **THEN** suppresses all output except errors

#### Scenario: Working directory
- **WHEN** user runs `laner --directory /path/to/project build`
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
