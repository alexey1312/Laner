# xcodebuild-executor Specification

## Purpose
TBD - created by archiving change init-laner-foundation. Update Purpose after archive.
## Requirements
### Requirement: Build Project
The system SHALL wrap xcodebuild to build iOS/macOS projects with type-safe options.

#### Scenario: Build workspace with scheme
- **WHEN** user calls `xcodebuild.build(workspace: "App.xcworkspace", scheme: "App")`
- **THEN** executes `xcodebuild build -workspace App.xcworkspace -scheme App`
- **AND** returns `BuildResult` with success status

#### Scenario: Build with configuration
- **WHEN** user calls `xcodebuild.build(workspace: "App.xcworkspace", scheme: "App", configuration: .release)`
- **THEN** executes with `-configuration Release`

#### Scenario: Build for simulator
- **WHEN** user calls `xcodebuild.build(..., destination: .simulator(name: "iPhone 15"))`
- **THEN** executes with `-destination 'platform=iOS Simulator,name=iPhone 15'`

#### Scenario: Build failure
- **WHEN** xcodebuild returns non-zero exit code
- **THEN** throws `XcodebuildError.buildFailed` with parsed error messages

### Requirement: Run Tests
The system SHALL wrap xcodebuild test action with result parsing.

#### Scenario: Run all tests
- **WHEN** user calls `xcodebuild.test(workspace: "App.xcworkspace", scheme: "AppTests")`
- **THEN** executes `xcodebuild test -workspace ... -scheme ...`
- **AND** returns `TestResult` with test counts

#### Scenario: Run specific test
- **WHEN** user calls `xcodebuild.test(..., testIdentifier: "MyTests/testFoo")`
- **THEN** executes with `-only-testing:MyTests/testFoo`

#### Scenario: Test with code coverage
- **WHEN** user calls `xcodebuild.test(..., codeCoverage: true)`
- **THEN** executes with `-enableCodeCoverage YES`

#### Scenario: Test failure
- **WHEN** tests fail
- **THEN** returns `TestResult` with failed test details

### Requirement: Archive for Distribution
The system SHALL create xcarchive for App Store or ad-hoc distribution.

#### Scenario: Create archive
- **WHEN** user calls `xcodebuild.archive(workspace: "App.xcworkspace", scheme: "App", archivePath: "build/App.xcarchive")`
- **THEN** executes `xcodebuild archive -archivePath build/App.xcarchive`
- **AND** returns `ArchiveResult` with archive path

#### Scenario: Archive with provisioning
- **WHEN** user specifies export options plist
- **THEN** uses `-exportOptionsPlist` for signing configuration

### Requirement: Export IPA
The system SHALL export IPA from xcarchive.

#### Scenario: Export for App Store
- **WHEN** user calls `xcodebuild.exportArchive(archivePath: "...", exportPath: "...", method: .appStore)`
- **THEN** executes `-exportArchive` with App Store export options
- **AND** returns path to generated IPA

#### Scenario: Export for ad-hoc
- **WHEN** user specifies `method: .adHoc`
- **THEN** export options use ad-hoc distribution

### Requirement: Build Options Structure
The system SHALL provide `Sendable` structs for all xcodebuild options.

#### Scenario: BuildOptions is Sendable
- **WHEN** BuildOptions struct is passed across actor boundaries
- **THEN** compilation succeeds without Sendable warnings

### Requirement: Platform Availability
The system SHALL only be available on macOS.

#### Scenario: Linux compilation
- **WHEN** compiling on Linux
- **THEN** XcodebuildExecutor is not available
- **AND** attempting to use it produces clear compile-time error

### Requirement: Real-time Build Output
The system SHALL stream xcodebuild output during execution.

#### Scenario: Progress reporting
- **WHEN** build is in progress
- **THEN** output is streamed to logger in real-time
- **AND** user sees compilation progress

