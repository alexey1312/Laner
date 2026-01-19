# Spec Delta: cli-commands

Modifications to cli-commands capability for lane execution.

Related spec: `openspec/specs/cli-commands/spec.md`

## ADDED Requirements

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
