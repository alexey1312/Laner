# ci-workflow Specification

## Purpose
TBD - created by archiving change init-swiftlane-foundation. Update Purpose after archive.
## Requirements
### Requirement: GitHub Actions CI Pipeline
The system SHALL provide a GitHub Actions workflow that runs build and tests on push and pull requests.

#### Scenario: CI triggers on push to main
- **WHEN** code is pushed to main branch
- **THEN** CI workflow is triggered
- **AND** builds the project with `swift build`
- **AND** runs tests with `swift test`

#### Scenario: CI triggers on pull request
- **WHEN** pull request is opened or updated targeting main
- **THEN** CI workflow is triggered
- **AND** builds and tests the changes

### Requirement: Multi-Version Swift Matrix
The system SHALL test against multiple Swift versions using a matrix strategy.

#### Scenario: Test on Swift 6.0
- **WHEN** CI runs
- **THEN** tests execute on Swift 6.0 with Xcode 16.0 on macos-15

#### Scenario: Test on Swift 6.1
- **WHEN** CI runs
- **THEN** tests execute on Swift 6.1 with Xcode 16.3 on macos-15

#### Scenario: Test on Swift 6.2
- **WHEN** CI runs
- **THEN** tests execute on Swift 6.2 with Xcode 26.0 on macos-26

### Requirement: Build and Test Steps
The system SHALL execute build and test as separate steps with verbose output.

#### Scenario: Build step
- **WHEN** CI reaches build step
- **THEN** executes `swift build -v`
- **AND** fails workflow if build fails

#### Scenario: Test step
- **WHEN** CI reaches test step
- **THEN** executes `swift test -v`
- **AND** fails workflow if tests fail

### Requirement: Fail-Fast Disabled
The system SHALL continue running all matrix jobs even if one fails.

#### Scenario: One Swift version fails
- **WHEN** tests fail on Swift 6.0
- **THEN** CI continues running Swift 6.1 and 6.2 jobs
- **AND** reports overall failure after all jobs complete

