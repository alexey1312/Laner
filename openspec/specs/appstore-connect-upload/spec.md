# appstore-connect-upload Specification

## Purpose

App Store Connect integration for TestFlight upload and build management using modern Build Upload API v4.1+. Enables chunked IPA uploads, build status tracking, and beta group distribution.

## Requirements

### Requirement: ChunkedUploader Actor

The system SHALL provide ChunkedUploader for uploading large files in chunks to App Store Connect.

#### Scenario: Upload IPA in chunks

- **GIVEN** a ChunkedUploader with an IPA file
- **WHEN** upload is called with app ID
- **THEN** file is split into 50MB chunks
- **AND** each chunk is uploaded to S3 via pre-signed URL
- **AND** progress callback is invoked for each chunk

#### Scenario: Retry failed chunks

- **GIVEN** a ChunkedUploader uploading a chunk
- **WHEN** upload fails with network error
- **THEN** chunk is retried up to 3 times
- **AND** exponential backoff is applied between retries

#### Scenario: Calculate MD5 checksums

- **GIVEN** a ChunkedUploader with chunk data
- **WHEN** preparing chunk for upload
- **THEN** MD5 checksum is calculated
- **AND** checksum is sent with upload request

### Requirement: TestFlightService Actor

The system SHALL provide TestFlightService for orchestrating TestFlight operations.

#### Scenario: Upload and wait for processing

- **GIVEN** a TestFlightService with IPA path
- **WHEN** uploadAndDistribute is called
- **THEN** IPA is uploaded via ChunkedUploader
- **AND** build processing status is polled
- **AND** returns when processing completes

#### Scenario: Distribute to beta groups

- **GIVEN** a TestFlightService with build ID and group names
- **WHEN** distribute is called
- **THEN** groups are resolved by name
- **AND** build is added to each group
- **AND** what's new notes are set if provided

#### Scenario: Processing timeout

- **GIVEN** a TestFlightService waiting for processing
- **WHEN** 30 minutes elapse without completion
- **THEN** TestFlightError.processingTimeout is thrown

### Requirement: Build Upload API Extension

The system SHALL extend AppStoreConnectAPI with build upload methods.

#### Scenario: Create build upload session

- **GIVEN** an AppStoreConnectAPI with valid credentials
- **WHEN** createBuildUpload is called with app ID
- **THEN** POST /v1/buildUploads creates session
- **AND** BuildUpload with ID and state is returned

#### Scenario: Reserve upload file

- **GIVEN** a build upload session ID
- **WHEN** reserveBuildUploadFile is called with chunk info
- **THEN** POST /v1/buildUploadFiles returns pre-signed URL
- **AND** BuildUploadFile with upload URL is returned

#### Scenario: Commit uploaded file

- **GIVEN** a file ID after successful S3 upload
- **WHEN** commitBuildUploadFile is called
- **THEN** PATCH /v1/buildUploadFiles/{id} marks file complete

#### Scenario: Complete build upload

- **GIVEN** all chunks committed
- **WHEN** completeBuildUpload is called
- **THEN** PATCH /v1/buildUploads/{id} triggers processing

### Requirement: Builds API Extension

The system SHALL extend AppStoreConnectAPI with build management methods.

#### Scenario: List builds for app

- **GIVEN** an AppStoreConnectAPI with valid credentials
- **WHEN** listBuilds is called with app ID
- **THEN** GET /v1/builds returns recent builds
- **AND** builds are sorted by upload date descending

#### Scenario: Get build by ID

- **GIVEN** a build ID
- **WHEN** getBuild is called
- **THEN** GET /v1/builds/{id} returns build details
- **AND** processing state is included

### Requirement: Beta Groups API Extension

The system SHALL extend AppStoreConnectAPI with beta group methods.

#### Scenario: List beta groups

- **GIVEN** an AppStoreConnectAPI with valid credentials
- **WHEN** listBetaGroups is called with app ID
- **THEN** GET /v1/betaGroups returns all groups
- **AND** internal vs external groups are identified

#### Scenario: Add build to group

- **GIVEN** a build ID and group ID
- **WHEN** addBuildToBetaGroup is called
- **THEN** POST to relationship endpoint adds build
- **AND** build becomes available to group testers

#### Scenario: Set beta test info

- **GIVEN** a build ID and what's new text
- **WHEN** setBetaTestInfo is called
- **THEN** localization is created or updated
- **AND** testers see what's new notes

### Requirement: PilotAction DSL Action

The system SHALL provide PilotAction for TestFlight upload in lanes.

#### Scenario: Upload IPA from options

- **GIVEN** PilotAction with ipa path
- **WHEN** action executes
- **THEN** IPA is uploaded to TestFlight
- **AND** PilotResult contains build information

#### Scenario: Distribute to groups

- **GIVEN** PilotAction with groups array
- **WHEN** action executes
- **THEN** build is added to specified groups
- **AND** changelog is set as what's new

#### Scenario: Skip processing wait

- **GIVEN** PilotAction with skipWaitingForProcessing: true
- **WHEN** action executes
- **THEN** returns immediately after upload
- **AND** does not poll for processing completion

#### Scenario: Resolve app ID from environment

- **GIVEN** PilotAction without explicit appId
- **AND** APP_STORE_APP_ID in environment
- **WHEN** action executes
- **THEN** app ID is read from environment

### Requirement: Upload CLI Command

The system SHALL provide `swiftlane upload testflight` CLI command.

#### Scenario: Upload with required options

- **GIVEN** command with --ipa flag
- **WHEN** command runs
- **THEN** IPA is uploaded to TestFlight
- **AND** progress is displayed during upload

#### Scenario: Upload with optional groups

- **GIVEN** command with --groups "Internal,External"
- **WHEN** command runs
- **THEN** build is distributed to specified groups

#### Scenario: Upload with changelog

- **GIVEN** command with --changelog "Bug fixes"
- **WHEN** command runs
- **THEN** what's new notes are set for testers

#### Scenario: Skip waiting flag

- **GIVEN** command with --skip-waiting
- **WHEN** command runs
- **THEN** returns after upload without waiting
- **AND** shows message about checking App Store Connect

#### Scenario: macOS only

- **GIVEN** command running on Linux
- **WHEN** command executes
- **THEN** error indicates macOS requirement
- **AND** exit code is failure

### Requirement: Model Types

The system MUST provide typed models for App Store Connect data.

#### Scenario: Build model

- **GIVEN** Build struct
- **THEN** it has properties: id, version, appVersion, processingState, uploadedDate, minOsVersion
- **AND** processingState is enum with PROCESSING, VALID, INVALID, FAILED

#### Scenario: BuildUpload model

- **GIVEN** BuildUpload struct
- **THEN** it has properties: id, uploadState
- **AND** uploadState is enum with AWAITING_FILES, UPLOADING, COMPLETE, FAILED

#### Scenario: BetaGroup model

- **GIVEN** BetaGroup struct
- **THEN** it has properties: id, name, isInternalGroup, publicLinkEnabled, publicLink

#### Scenario: UploadProgress struct

- **GIVEN** UploadProgress struct
- **THEN** it has properties: bytesUploaded, totalBytes, currentChunk, totalChunks
- **AND** percentage computed property returns 0-100

### Requirement: Error Handling

The system MUST provide descriptive errors for TestFlight operations.

#### Scenario: IPA not found

- **GIVEN** TestFlightService with invalid IPA path
- **WHEN** upload is called
- **THEN** TestFlightError.ipaNotFound is thrown
- **AND** error message includes path

#### Scenario: Group not found

- **GIVEN** TestFlightService with unknown group name
- **WHEN** distribute is called
- **THEN** TestFlightError.groupNotFound is thrown
- **AND** error message includes group name

#### Scenario: Missing credentials

- **GIVEN** PilotAction without API credentials
- **AND** environment variables not set
- **WHEN** action executes
- **THEN** TestFlightError.missingCredentials is thrown
- **AND** error indicates which credential is missing
