# logging Specification

## Purpose
TBD - created by archiving change init-swiftlane-foundation. Update Purpose after archive.
## Requirements
### Requirement: Structured Logging
The system SHALL use swift-log for structured logging with category support.

#### Scenario: Log with category
- **WHEN** code calls `Logger.swiftlane(.shell).info("Running command")`
- **THEN** log entry includes category "shell"

#### Scenario: Log levels
- **WHEN** using different log levels (trace, debug, info, notice, warning, error, critical)
- **THEN** messages are filtered according to configured level

### Requirement: Log Categories
The system SHALL define standard categories for different subsystems.

#### Scenario: Available categories
- **WHEN** logging throughout the system
- **THEN** these categories are available:
  - `.shell` — process execution
  - `.xcodebuild` — build/test operations
  - `.cli` — command parsing and execution
  - `.dsl` — lane and action execution
  - `.config` — configuration loading

### Requirement: Console Output Formatting
The system SHALL format console output for readability.

#### Scenario: Colored output
- **WHEN** terminal supports colors
- **THEN** log levels use appropriate colors (red for errors, yellow for warnings)

#### Scenario: Plain output
- **WHEN** output is piped or terminal doesn't support colors
- **THEN** uses plain text without ANSI codes

#### Scenario: Timestamp formatting
- **WHEN** verbose mode enabled
- **THEN** includes timestamp in log output

### Requirement: Build Output Streaming
The system SHALL stream build output with appropriate formatting.

#### Scenario: Xcodebuild output
- **WHEN** xcodebuild is running
- **THEN** output is streamed in real-time
- **AND** errors are highlighted

#### Scenario: Quiet mode filtering
- **WHEN** quiet mode is enabled
- **THEN** only errors and final results are shown

### Requirement: Progress Indication
The system SHALL indicate progress for long-running operations.

#### Scenario: Build progress
- **WHEN** build is in progress
- **THEN** shows current phase (compiling, linking, signing)

#### Scenario: Spinner for waiting
- **WHEN** waiting for external operation
- **THEN** shows animated spinner (if terminal supports it)

### Requirement: Log File Output
The system SHALL support writing logs to file.

#### Scenario: Enable file logging
- **WHEN** user runs `swiftlane --log-file build.log build`
- **THEN** all logs are written to build.log

#### Scenario: Log rotation
- **WHEN** log file exceeds 10MB
- **THEN** rotates to build.log.1, build.log.2, etc.

### Requirement: CI-Friendly Output
The system SHALL adapt output for CI environments.

#### Scenario: GitHub Actions grouping
- **WHEN** running in GitHub Actions
- **THEN** uses `::group::` and `::endgroup::` for collapsible sections

#### Scenario: No interactive elements in CI
- **WHEN** running in CI
- **THEN** disables spinners and progress bars

