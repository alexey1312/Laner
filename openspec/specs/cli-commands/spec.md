# cli-commands Specification

## Purpose

TBD - created by archiving change init-laner-foundation. Update Purpose after archive.

## Requirements

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

### Requirement: Init Command

The system SHALL provide an `init` command to scaffold Laner configuration.

#### Scenario: Initialize in empty project

- **GIVEN** a project without Laner directory
- **WHEN** user runs `laner init`
- **THEN** `Laner/` directory is created
- **AND** `Laner/Lanerfile.swift` is created with template
- **AND** success message is printed

#### Scenario: Initialize in existing project

- **GIVEN** a project with existing Laner directory
- **WHEN** user runs `laner init`
- **THEN** error "Laner already initialized" is printed
- **AND** hint to use --force is shown

#### Scenario: Force reinitialize

- **GIVEN** a project with existing Laner directory
- **WHEN** user runs `laner init --force`
- **THEN** existing Lanerfile.swift is overwritten
- **AND** warning about overwrite is printed

### Requirement: Lane Execution Command

The system SHALL provide a `lane` command to execute a named lane.

#### Scenario: Execute named lane

- **GIVEN** Lanerfile.swift with lane "build"
- **WHEN** user runs `laner lane build`
- **THEN** manifest is compiled (if not cached)
- **AND** the "build" lane is executed
- **AND** exit code 0 on success

#### Scenario: First run compilation

- **GIVEN** Lanerfile.swift not yet compiled
- **WHEN** user runs `laner lane build`
- **THEN** "Compiling Lanerfile..." is printed
- **AND** compilation progress is shown
- **AND** lane executes after compilation

#### Scenario: Cached run

- **GIVEN** Lanerfile.swift previously compiled and unchanged
- **WHEN** user runs `laner lane build`
- **THEN** cached executable is used
- **AND** no compilation message is shown
- **AND** lane executes immediately

#### Scenario: Lane not found

- **GIVEN** Lanerfile.swift without lane "deploy"
- **WHEN** user runs `laner lane deploy`
- **THEN** error "Lane 'deploy' not found" is printed
- **AND** available lanes are listed
- **AND** exit code 1

#### Scenario: Lane execution failure

- **GIVEN** lane "build" with failing action
- **WHEN** user runs `laner lane build`
- **THEN** error details are printed
- **AND** lane execution stops at first failure
- **AND** exit code 1

#### Scenario: Verbose lane output

- **GIVEN** lane "build" with multiple actions
- **WHEN** user runs `laner lane build --verbose`
- **THEN** each action start/end is logged
- **AND** action durations are shown
- **AND** total lane duration is shown

### Requirement: List Lanes Command

The system SHALL provide a `lanes` command to list available lanes.

#### Scenario: List all lanes

- **GIVEN** Lanerfile.swift with lanes "build", "test", "deploy"
- **WHEN** user runs `laner lanes`
- **THEN** output shows:

```
Available lanes:
  build   - Build the application
  test    - Run unit tests
  deploy  - Deploy to TestFlight
```

#### Scenario: No manifest found

- **GIVEN** no Laner directory in working directory
- **WHEN** user runs `laner lanes`
- **THEN** error "No Lanerfile.swift found" is printed
- **AND** hint "Run 'laner init' to create one" is shown

#### Scenario: Empty lanes

- **GIVEN** Lanerfile.swift with empty lanes array
- **WHEN** user runs `laner lanes`
- **THEN** output shows "No lanes defined"
- **AND** hint to add lanes is shown

#### Scenario: Compilation error in manifest

- **GIVEN** Lanerfile.swift with syntax errors
- **WHEN** user runs `laner lanes`
- **THEN** compilation errors are displayed
- **AND** file:line references are included
- **AND** exit code 1

### Requirement: Manifest Path Option

Commands MUST support custom manifest path.

#### Scenario: Custom manifest path

- **GIVEN** manifest at /custom/path/Lanerfile.swift
- **WHEN** user runs `laner lanes --manifest /custom/path/Lanerfile.swift`
- **THEN** specified manifest is loaded
- **AND** lanes are listed

#### Scenario: Invalid manifest path

- **GIVEN** non-existent path /invalid/path.swift
- **WHEN** user runs `laner lanes --manifest /invalid/path.swift`
- **THEN** error "Manifest file not found: /invalid/path.swift" is printed
- **AND** exit code 1

### Requirement: Match Command

The system SHALL provide a `match` command for code signing management.

#### Scenario: Sync certificates and profiles

- **GIVEN** environment variables MATCH_GIT_URL, MATCH_TEAM_ID, MATCH_PASSWORD are set
- **WHEN** user runs `laner match sync --type development`
- **THEN** downloads certificates from Git repository
- **AND** installs certificates to keychain
- **AND** installs provisioning profiles
- **AND** displays sync results

#### Scenario: Sync with app identifier

- **GIVEN** Match configuration is valid
- **WHEN** user runs `laner match sync --type appstore --app-identifier com.example.app`
- **THEN** syncs only profiles for specified app identifier
- **AND** displays filtered results

#### Scenario: Sync in readonly mode

- **GIVEN** Match configuration is valid
- **WHEN** user runs `laner match sync --type adhoc --readonly`
- **THEN** downloads existing certificates without creating new ones
- **AND** fails if certificates are missing

#### Scenario: Initialize Match repository

- **GIVEN** empty Git repository exists
- **WHEN** user runs `laner match init --git-url <url> --team-id <id>`
- **THEN** creates directory structure in repository
- **AND** displays environment variable setup instructions

#### Scenario: Nuke certificates

- **GIVEN** Match configuration is valid
- **WHEN** user runs `laner match nuke --type development`
- **AND** confirms with "yes"
- **THEN** revokes all development certificates from App Store Connect
- **AND** deletes provisioning profiles
- **AND** removes files from Git repository
- **AND** displays count of revoked certificates and deleted profiles

#### Scenario: Nuke with force flag

- **GIVEN** Match configuration is valid
- **WHEN** user runs `laner match nuke --type distribution --force`
- **THEN** skips confirmation prompt
- **AND** proceeds with revocation

#### Scenario: Register devices from file

- **GIVEN** devices.txt with format "Name\tUDID" per line
- **WHEN** user runs `laner match register --devices-file devices.txt`
- **THEN** registers new devices with App Store Connect
- **AND** displays newly registered and existing devices

#### Scenario: Register devices with platform

- **GIVEN** devices file exists
- **WHEN** user runs `laner match register --devices-file devices.txt --platform tvOS`
- **THEN** registers devices for tvOS platform

#### Scenario: Change encryption password

- **GIVEN** MATCH_PASSWORD is set to current password
- **WHEN** user runs `laner match change-password --new-password <new>`
- **THEN** decrypts all files with old password
- **AND** re-encrypts with new password
- **AND** commits changes to Git repository
- **AND** displays success message

#### Scenario: Missing required environment variable

- **GIVEN** MATCH_PASSWORD is not set
- **WHEN** user runs `laner match sync --type development`
- **THEN** error "Missing environment variable: MATCH_PASSWORD" is displayed
- **AND** exit code 1

#### Scenario: Invalid certificate type

- **GIVEN** Match configuration is valid
- **WHEN** user runs `laner match sync --type invalid`
- **THEN** error "Invalid certificate type: invalid" is displayed
- **AND** lists valid types: development, distribution, adhoc, appstore
- **AND** exit code 1

#### Scenario: Override configuration with CLI args

- **GIVEN** MATCH_GIT_URL environment variable is set
- **WHEN** user runs `laner match sync --type development --git-url <different-url>`
- **THEN** uses CLI-provided Git URL instead of environment variable

#### Scenario: Custom Git branch

- **GIVEN** Match configuration is valid
- **WHEN** user runs `laner match sync --type development --branch feature-branch`
- **THEN** uses feature-branch for Git operations
