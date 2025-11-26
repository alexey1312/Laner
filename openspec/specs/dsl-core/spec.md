# dsl-core Specification

## Purpose
TBD - created by archiving change init-swiftlane-foundation. Update Purpose after archive.
## Requirements
### Requirement: Lane Definition
The system SHALL provide a `Lane` type for defining CI/CD workflows.

#### Scenario: Define simple lane
- **WHEN** user creates `Lane("build", actions: [buildAction])`
- **THEN** lane is created with name "build" and one action

#### Scenario: Lane with description
- **WHEN** user creates `Lane("deploy", description: "Deploy to TestFlight")`
- **THEN** lane includes description for documentation

### Requirement: Action Protocol
The system SHALL define an `Action` protocol for CI/CD operations.

#### Scenario: Implement custom action
- **WHEN** developer creates type conforming to `Action`
- **THEN** action can be used in lanes
- **AND** action has `name`, `execute(context:)` method

#### Scenario: Action with async execution
- **WHEN** Action type defines async execute method
- **THEN** action can perform async operations (shell, network)

### Requirement: Execution Context
The system SHALL provide execution context to actions.

#### Scenario: Access shell executor
- **WHEN** action executes
- **THEN** context provides `shell: ShellExecutor`

#### Scenario: Access logger
- **WHEN** action executes
- **THEN** context provides `logger: Logger`

#### Scenario: Access environment
- **WHEN** action executes
- **THEN** context provides `environment: Environment` with env vars and CI detection

### Requirement: Environment Detection
The system SHALL detect CI environment and provide environment variables.

#### Scenario: Detect GitHub Actions
- **WHEN** running in GitHub Actions
- **THEN** `environment.isCI` returns true
- **AND** `environment.ciProvider` returns `.githubActions`

#### Scenario: Detect local development
- **WHEN** running locally
- **THEN** `environment.isCI` returns false

#### Scenario: Access environment variable
- **WHEN** user calls `environment["MY_VAR"]`
- **THEN** returns value of MY_VAR or nil

### Requirement: Artifact Storage
The system SHALL allow actions to share artifacts.

#### Scenario: Store build artifact
- **WHEN** action calls `context.addArtifact(Artifact(type: .ipa, path: "/path/to/app.ipa"))`
- **THEN** artifact is stored in context

#### Scenario: Retrieve artifact
- **WHEN** subsequent action calls `context.artifact(ofType: .ipa)`
- **THEN** returns previously stored IPA artifact

### Requirement: SwiftlaneConfiguration Protocol
The system SHALL define protocol for user configuration files.

#### Scenario: Minimal configuration
- **WHEN** user creates type conforming to `SwiftlaneConfiguration`
- **THEN** must provide `static var lanes: [Lane]`

#### Scenario: Lifecycle hooks
- **WHEN** configuration implements `beforeAll(lane:)`
- **THEN** hook is called before lane execution

#### Scenario: Error handling hook
- **WHEN** configuration implements `onError(lane:error:)`
- **THEN** hook is called when lane fails

### Requirement: Type-Safe Options
The system SHALL support type-safe options for actions.

#### Scenario: Action with options
- **WHEN** action defines `Options: Codable`
- **THEN** options are validated at compile time

#### Scenario: Lane with options
- **WHEN** lane accepts options `Lane("upload", options: UploadOptions.self)`
- **THEN** options can be passed from CLI

