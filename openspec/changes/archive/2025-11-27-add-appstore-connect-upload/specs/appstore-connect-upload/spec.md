# appstore-connect-upload Specification

## Purpose

Laner App Store Connect Upload provides IPA upload to TestFlight and basic build management. Uses modern Build Upload API v4.1+ with chunked uploads and API Key authentication.

## Architecture

```toon
components[4]{name,description}:
  ChunkedUploader,Actor for chunked file uploads via Build Upload API v4.1+
  TestFlightService,Orchestrates upload and distribution
  AppStoreConnectAPI,Extended API for builds and beta groups
  PilotAction,DSL action for TestFlight upload
```

## ADDED Requirements

### Requirement: IPA Upload

The system SHALL upload IPA files to App Store Connect using Build Upload API v4.1+.

#### Scenario: Upload IPA to TestFlight

- **GIVEN** valid IPA file at path
- **AND** APP_STORE_CONNECT_API_KEY_ID, API_ISSUER_ID, API_KEY_PATH environment variables set
- **WHEN** upload is called
- **THEN** creates build upload via POST /v1/buildUploads
- **AND** splits IPA into 50MB chunks
- **AND** for each chunk: reserves file, uploads to S3, commits
- **AND** completes upload via POST /v1/buildUploads/{id}/complete
- **AND** logs progress during upload

#### Scenario: Upload with progress tracking

- **GIVEN** IPA file being uploaded
- **WHEN** chunk uploads complete
- **THEN** reports UploadProgress with bytesUploaded, totalBytes, percentage

#### Scenario: Chunk upload failure with retry

- **GIVEN** chunk upload fails
- **WHEN** error is transient
- **THEN** retries with exponential backoff (3 attempts max)
- **AND** throws TestFlightError.chunkUploadFailed if all retries fail

#### Scenario: IPA file not found

- **GIVEN** IPA path that does not exist
- **WHEN** upload is called
- **THEN** throws TestFlightError.ipaNotFound(path)

### Requirement: Build Management

The system SHALL query builds via App Store Connect API.

#### Scenario: List builds for app

- **GIVEN** AppStoreConnectAPI with valid credentials
- **WHEN** listBuilds is called with appId
- **THEN** makes GET request to /v1/builds
- **AND** returns array of Build objects with id, version, processingState

#### Scenario: Get build processing status

- **GIVEN** build ID
- **WHEN** getBuild is called
- **THEN** makes GET request to /v1/builds/{id}
- **AND** returns Build with processingState

#### Scenario: Wait for build processing

- **GIVEN** uploaded build in PROCESSING state
- **WHEN** waitForProcessing is called
- **THEN** polls GET /v1/builds every 30 seconds
- **AND** returns when processingState becomes VALID
- **AND** throws TestFlightError.processingTimeout after 30 minutes

### Requirement: TestFlight Distribution

The system SHALL distribute builds to TestFlight testers.

#### Scenario: Add build to beta group

- **GIVEN** processed build ID and beta group ID
- **WHEN** addBuildToBetaGroup is called
- **THEN** makes POST request to link build to group
- **AND** testers in group receive notification

#### Scenario: List beta groups

- **GIVEN** app ID
- **WHEN** listBetaGroups is called
- **THEN** makes GET request to /v1/betaGroups
- **AND** returns array of BetaGroup with id, name

#### Scenario: Set beta test information

- **GIVEN** build ID and changelog text
- **WHEN** setBetaTestInfo is called
- **THEN** makes PATCH request to set whatsNew field

### Requirement: pilot DSL Action

The system SHALL provide pilot() action for TestFlight uploads.

#### Scenario: Basic pilot usage

```swift
lane("beta") {
    gym(scheme: "App", exportMethod: .adHoc)
    pilot()
}
```

- **GIVEN** lane with gym and pilot
- **WHEN** lane executes
- **THEN** pilot finds IPA from gym artifacts
- **AND** uploads to TestFlight

#### Scenario: Pilot with options

- **GIVEN** pilot(ipa: "build/App.ipa", changelog: "Bug fixes", groups: ["QA"])
- **WHEN** action executes
- **THEN** uploads specified IPA
- **AND** sets whatsNew
- **AND** distributes to specified groups

### Requirement: CLI Upload Command

The system SHALL provide CLI command for TestFlight upload.

#### Scenario: Upload command

- **GIVEN** `laner upload testflight --ipa App.ipa`
- **WHEN** command executes
- **THEN** uploads IPA to TestFlight
- **AND** displays progress
- **AND** displays success with build version

#### Scenario: Upload with options

- **GIVEN** `laner upload testflight --ipa App.ipa --groups "QA" --changelog "Fixes"`
- **WHEN** command executes
- **THEN** uploads and distributes to groups

### Requirement: Configuration

The system SHALL reuse existing Match configuration.

#### Scenario: Configuration from environment

- **GIVEN** APP_STORE_CONNECT_API_KEY_ID, API_ISSUER_ID, API_KEY_PATH set
- **WHEN** TestFlightService is initialized
- **THEN** uses existing AppStoreConnectAPI configuration

### Requirement: Rate Limiting

The system SHALL handle API rate limiting gracefully.

#### Scenario: Rate limit response

- **GIVEN** API returns 429 Too Many Requests
- **WHEN** Retry-After header is present
- **THEN** waits for specified duration
- **AND** retries request
- **AND** throws TestFlightError.rateLimited if limit exceeded

### Requirement: Platform Support

The system SHALL support both macOS and Linux.

#### Scenario: macOS execution

- **GIVEN** macOS system
- **WHEN** `laner upload testflight` is executed
- **THEN** performs full upload workflow

#### Scenario: Linux execution

- **GIVEN** Linux system
- **WHEN** `laner upload testflight` is executed
- **THEN** performs upload via Build Upload API (no Keychain required)
- **AND** IPA must be pre-signed

## MODIFIED Requirements

### Requirement: Built-in Actions (extends built-in-actions spec)

The system SHALL extend built-in actions with pilot() for TestFlight uploads.

#### Scenario: pilot() DSL function

- **GIVEN** pilot() DSL function
- **WHEN** called with ipa, appId, changelog, groups, skipWaitingForProcessing parameters
- **THEN** creates AnyAction wrapping PilotAction

### Requirement: CLI Commands (extends cli-commands spec)

The system SHALL extend CLI commands with upload subcommand for TestFlight.

#### Scenario: Upload subcommand

- **GIVEN** `laner upload` command
- **THEN** provides subcommand: testflight
- **AND** testflight requires --ipa option
- **AND** supports optional: --app-id, --changelog, --groups, --skip-waiting
