# shell-executor Specification

## Purpose

TBD - created by archiving change init-laner-foundation. Update Purpose after archive.

## Requirements

### Requirement: Async Process Execution

The system SHALL provide an actor-based shell executor that runs external processes asynchronously with proper isolation.

#### Scenario: Execute simple command

- **WHEN** user calls `shell.run("echo", arguments: ["hello"])`
- **THEN** the command executes asynchronously
- **AND** returns `ProcessResult` with stdout containing "hello"

#### Scenario: Command with non-zero exit

- **WHEN** user calls `shell.run("false", arguments: [])`
- **THEN** the command executes
- **AND** returns `ProcessResult` with exitCode != 0

#### Scenario: Command not found

- **WHEN** user calls `shell.run("nonexistent-command", arguments: [])`
- **THEN** throws `ShellError.commandNotFound`

### Requirement: Streaming Output

The system SHALL support streaming stdout/stderr for long-running processes via `AsyncThrowingStream`.

#### Scenario: Stream build output

- **WHEN** user calls `shell.stream("xcodebuild", arguments: [...])`
- **THEN** returns `AsyncThrowingStream<String, Error>`
- **AND** each line is yielded as it becomes available
- **AND** stream completes when process exits

#### Scenario: Stream with error

- **WHEN** streaming process fails mid-execution
- **THEN** stream throws error with last captured output

### Requirement: Process Result Structure

The system SHALL provide a `Sendable` struct containing execution results.

#### Scenario: Successful execution result

- **WHEN** process completes successfully
- **THEN** `ProcessResult` contains:
  - `exitCode: Int32` (0 for success)
  - `stdout: String` (captured output)
  - `stderr: String` (captured errors)
  - `duration: Duration` (execution time)

### Requirement: Working Directory Support

The system SHALL allow specifying working directory for process execution.

#### Scenario: Execute in specific directory

- **WHEN** user calls `shell.run("pwd", arguments: [], workingDirectory: "/tmp")`
- **THEN** command executes in `/tmp`
- **AND** stdout contains "/tmp"

### Requirement: Environment Variables

The system SHALL support custom environment variables for process execution.

#### Scenario: Pass custom environment

- **WHEN** user calls `shell.run("printenv", arguments: ["FOO"], environment: ["FOO": "bar"])`
- **THEN** stdout contains "bar"

### Requirement: Process Timeout

The system SHALL support optional timeout for process execution.

#### Scenario: Process exceeds timeout

- **WHEN** user calls `shell.run("sleep", arguments: ["10"], timeout: .seconds(1))`
- **THEN** process is terminated after 1 second
- **AND** throws `ShellError.timeout`
