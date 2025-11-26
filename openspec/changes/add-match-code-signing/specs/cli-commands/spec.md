## ADDED Requirements

### Requirement: Match Command Group

The system SHALL provide a `laner match` command group for code signing management.

#### Scenario: Match sync subcommand

- **WHEN** user runs `laner match sync --type appstore`
- **THEN** certificates of specified type are downloaded from Git
- **AND** installed to Keychain
- **AND** success summary is displayed

#### Scenario: Match sync with app identifier

- **WHEN** user runs `laner match sync --type adhoc --app-identifier com.example.app`
- **THEN** only profiles for specified app are synced

#### Scenario: Match sync readonly

- **WHEN** user runs `laner match sync --type development --readonly`
- **THEN** certificates are synced
- **AND** no new certificates are created if missing
- **AND** Git repository is not modified

#### Scenario: Match init subcommand

- **WHEN** user runs `laner match init`
- **THEN** interactive prompts collect:
  - Git repository URL
  - Team ID
  - App identifiers
- **AND** `Laner/MatchConfig.swift` is created

#### Scenario: Match nuke subcommand

- **WHEN** user runs `laner match nuke --type development`
- **THEN** confirmation prompt is shown
- **AND** on confirmation, certificates are revoked
- **AND** files removed from Git repository

#### Scenario: Match register subcommand

- **WHEN** user runs `laner match register --devices devices.txt`
- **THEN** devices from file are registered via API
- **AND** registration count is displayed

#### Scenario: Match change-password subcommand

- **WHEN** user runs `laner match change-password`
- **THEN** prompts for current and new password
- **AND** re-encrypts all files in repository
- **AND** pushes updated files

#### Scenario: Match help

- **WHEN** user runs `laner match --help`
- **THEN** available subcommands are listed:
  - sync, init, nuke, register, change-password
- **AND** brief description for each is shown

### Requirement: Match Environment Variables

The system SHALL support environment variables for Match configuration.

#### Scenario: MATCH_PASSWORD

- **GIVEN** `MATCH_PASSWORD` environment variable set
- **WHEN** match sync is executed
- **THEN** value is used for encryption/decryption

#### Scenario: MATCH_GIT_URL

- **GIVEN** `MATCH_GIT_URL` environment variable set
- **WHEN** match sync is executed without --git-url
- **THEN** environment variable URL is used

#### Scenario: MATCH_GIT_BASIC_AUTHORIZATION

- **GIVEN** `MATCH_GIT_BASIC_AUTHORIZATION` set (base64 encoded)
- **WHEN** Git operations require auth
- **THEN** basic auth header is constructed from value

#### Scenario: Missing MATCH_PASSWORD

- **GIVEN** `MATCH_PASSWORD` not set
- **AND** no --password argument provided
- **WHEN** user runs `laner match sync`
- **THEN** error "MATCH_PASSWORD required" is displayed
