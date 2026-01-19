# built-in-actions Specification

## Purpose

TBD - created by archiving change add-lane-execution. Update Purpose after archive.

## Requirements

### Requirement: GymAction for Building

The system SHALL provide GymAction wrapping XcodebuildExecutor.build for project builds.

#### Scenario: Build with scheme

- **GIVEN** a GymAction with scheme "App"
- **WHEN** the action executes
- **THEN** XcodebuildExecutor.build is called with scheme "App"
- **AND** BuildResult is returned

#### Scenario: Build with workspace

- **GIVEN** a GymAction with workspace "App.xcworkspace" and scheme "App"
- **WHEN** the action executes
- **THEN** XcodebuildExecutor.build uses the workspace path
- **AND** the scheme is applied

#### Scenario: Build with configuration

- **GIVEN** a GymAction with configuration "Release"
- **WHEN** the action executes
- **THEN** XcodebuildExecutor.build uses Release configuration
- **AND** optimizations are enabled

#### Scenario: Build failure handling

- **GIVEN** a GymAction that encounters a build error
- **WHEN** the action executes
- **THEN** the error is propagated
- **AND** build logs are available in the result

### Requirement: ScanAction for Testing

The system SHALL provide ScanAction wrapping XcodebuildExecutor.test for running tests.

#### Scenario: Run all tests

- **GIVEN** a ScanAction with scheme "AppTests"
- **WHEN** the action executes
- **THEN** XcodebuildExecutor.test runs all tests
- **AND** TestResult contains pass/fail counts

#### Scenario: Run tests with code coverage

- **GIVEN** a ScanAction with codeCoverage enabled
- **WHEN** the action executes
- **THEN** code coverage data is collected
- **AND** coverage report path is in result

#### Scenario: Run tests on specific device

- **GIVEN** a ScanAction with device "iPhone 15"
- **WHEN** the action executes
- **THEN** tests run on iPhone 15 simulator
- **AND** destination is properly formatted

#### Scenario: Test failure handling

- **GIVEN** a ScanAction with failing tests
- **WHEN** the action executes
- **THEN** failed test names are in result
- **AND** error is thrown for lane failure

### Requirement: ArchiveAction for Distribution

The system SHALL provide ArchiveAction wrapping XcodebuildExecutor.archive for creating archives.

#### Scenario: Create archive

- **GIVEN** an ArchiveAction with scheme "App"
- **WHEN** the action executes
- **THEN** XcodebuildExecutor.archive creates an xcarchive
- **AND** archive path is added to artifacts

#### Scenario: Archive with export options

- **GIVEN** an ArchiveAction with exportMethod "app-store"
- **WHEN** the action executes
- **THEN** export options plist is generated
- **AND** IPA is created for App Store

#### Scenario: Archive artifact registration

- **GIVEN** an ArchiveAction that succeeds
- **WHEN** the action completes
- **THEN** an Artifact of type xcarchive is added to context
- **AND** artifact path points to the archive location

### Requirement: Action Options Structs

The system MUST provide typed options structs for each action.

#### Scenario: GymOptions structure

- **GIVEN** GymOptions struct
- **THEN** it has properties: scheme, workspace, project, configuration, destination, derivedDataPath, clean
- **AND** all properties are optional except scheme

#### Scenario: ScanOptions structure

- **GIVEN** ScanOptions struct
- **THEN** it has properties: scheme, workspace, project, devices, codeCoverage, retryCount
- **AND** scheme is required

#### Scenario: ArchiveOptions structure

- **GIVEN** ArchiveOptions struct
- **THEN** it has properties: scheme, workspace, project, configuration, archivePath, exportMethod, teamId
- **AND** scheme is required

### Requirement: Platform Availability

Actions MUST handle platform restrictions gracefully.

#### Scenario: macOS-only actions

- **GIVEN** GymAction, ScanAction, ArchiveAction
- **WHEN** compiled on Linux
- **THEN** actions are available but throw platform error on execute
- **AND** error message indicates macOS requirement

### Requirement: MatchAction for Code Signing

The system SHALL provide MatchAction wrapping Match code signing functionality.

#### Scenario: Sync certificates in lane

- **GIVEN** a MatchAction with type .appstore
- **WHEN** the action executes
- **THEN** Match downloads certificates from Git repository
- **AND** installs certificates to keychain
- **AND** installs provisioning profiles
- **AND** SyncResult contains certificate and profile lists

#### Scenario: Sync with readonly mode

- **GIVEN** a MatchAction with readonly: true
- **WHEN** the action executes
- **THEN** Match uses existing certificates only
- **AND** no new certificates are created
- **AND** fails if required certificates are missing

#### Scenario: Sync for specific app

- **GIVEN** a MatchAction with appIdentifier: "com.example.app"
- **WHEN** the action executes
- **THEN** only profiles for specified app are synced
- **AND** result contains filtered profiles

#### Scenario: Sync with force for new devices

- **GIVEN** a MatchAction with forceForNewDevices: true
- **WHEN** the action executes
- **THEN** provisioning profiles are regenerated
- **AND** new device UDIDs are included in profiles

#### Scenario: Configuration from environment

- **GIVEN** MATCH_GIT_URL, MATCH_TEAM_ID, MATCH_PASSWORD in environment
- **AND** MatchAction without explicit configuration
- **WHEN** the action executes
- **THEN** configuration is read from environment variables

#### Scenario: Configuration override

- **GIVEN** environment variables are set
- **AND** MatchAction with explicit gitUrl, teamId, password
- **WHEN** the action executes
- **THEN** explicit options override environment variables

#### Scenario: Missing required configuration

- **GIVEN** MatchAction without password
- **AND** MATCH_PASSWORD not in environment
- **WHEN** the action executes
- **THEN** MatchActionError.missingPassword is thrown

#### Scenario: Custom Git branch

- **GIVEN** MatchAction with branch: "feature-branch"
- **WHEN** the action executes
- **THEN** Match uses specified branch for Git operations

#### Scenario: Certificate types

- **GIVEN** MatchAction with different types
- **WHEN** action executes with type .development, .distribution, .adhoc, or .appstore
- **THEN** appropriate certificate type is synced
- **AND** corresponding provisioning profiles are installed

### Requirement: RegisterDevicesAction for Device Management

The system SHALL provide RegisterDevicesAction for device registration.

#### Scenario: Register devices from file

- **GIVEN** RegisterDevicesAction with file path
- **AND** file contains "Name\tUDID" per line
- **WHEN** the action executes
- **THEN** devices are registered with App Store Connect
- **AND** RegisterDevicesResult contains registered and existing device lists

#### Scenario: Register devices from dictionary

- **GIVEN** RegisterDevicesAction with devices dictionary
- **WHEN** the action executes
- **THEN** devices are registered with App Store Connect
- **AND** result shows newly registered vs. existing

#### Scenario: Register for specific platform

- **GIVEN** RegisterDevicesAction with platform: .tvOS
- **WHEN** the action executes
- **THEN** devices are registered for tvOS platform

#### Scenario: Multiple device platforms

- **GIVEN** RegisterDevicesAction with different platforms
- **WHEN** action executes with platform .iOS, .macOS, or .tvOS
- **THEN** devices are registered for correct platform

#### Scenario: API credentials from environment

- **GIVEN** APP_STORE_CONNECT_API_KEY_ID, API_ISSUER_ID, API_KEY_PATH in environment
- **AND** RegisterDevicesAction without explicit credentials
- **WHEN** the action executes
- **THEN** credentials are read from environment variables

#### Scenario: Missing API credentials

- **GIVEN** RegisterDevicesAction without API key
- **AND** APP_STORE_CONNECT_API_KEY_ID not in environment
- **WHEN** the action executes
- **THEN** RegisterDevicesActionError.missingApiKeyId is thrown

#### Scenario: No device source provided

- **GIVEN** RegisterDevicesAction without file or devices
- **WHEN** the action executes
- **THEN** RegisterDevicesActionError.noDeviceSource is thrown

#### Scenario: Device registration with Match workflow

- **GIVEN** lane with registerDevices and match actions
- **WHEN** lane executes
- **THEN** devices are registered first
- **AND** match regenerates profiles with forceForNewDevices: true
- **AND** new devices are included in profiles

### Requirement: Match and RegisterDevices Options Structs

The system MUST provide typed options structs for Match actions.

#### Scenario: MatchOptions structure

- **GIVEN** MatchOptions struct
- **THEN** it has properties: type, readonly, appIdentifier, teamId, gitUrl, forceForNewDevices, branch, password
- **AND** type is required
- **AND** all others are optional with defaults

#### Scenario: RegisterDevicesOptions structure

- **GIVEN** RegisterDevicesOptions struct
- **THEN** it has properties: file, devices, platform, teamId, apiKeyId, apiIssuerId, apiKeyPath
- **AND** either file or devices is required
- **AND** platform defaults to iOS

### Requirement: DSL Functions

The system MUST provide DSL functions for Match actions.

#### Scenario: match() function

- **GIVEN** match() DSL function
- **WHEN** called with type, appIdentifier, readonly parameters
- **THEN** creates AnyAction wrapping MatchAction
- **AND** can be used in lane builder

#### Scenario: registerDevices() with file

- **GIVEN** registerDevices(file:) DSL function
- **WHEN** called with file path
- **THEN** creates AnyAction wrapping RegisterDevicesAction
- **AND** can be used in lane builder

#### Scenario: registerDevices() with dictionary

- **GIVEN** registerDevices(devices:) DSL function
- **WHEN** called with device dictionary
- **THEN** creates AnyAction wrapping RegisterDevicesAction
- **AND** can be used in lane builder
