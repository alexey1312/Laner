# Spec: built-in-actions

Built-in actions wrapping XcodebuildExecutor functionality.

## ADDED Requirements

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
