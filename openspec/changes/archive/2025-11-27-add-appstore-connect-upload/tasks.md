# Tasks: add-appstore-connect-upload

## Summary

App Store Connect integration for TestFlight upload and basic build management. Uses modern Build Upload API v4.1+ with chunked uploads. Phase 4 implementation from IMPLEMENTATION_PLAN.md.

---

## Phase 1: Build Upload (MVP)

### 1.1 API Models

- [x] Create Build model (id, version, processingState, uploadedDate, minOsVersion)
- [x] Create BuildUpload model (id, uploadState)
- [x] Create BuildUploadFile model (id, uploadUrl, fileId)
- [x] Create BetaGroup model (id, name, isInternalGroup)
- [x] Create TestFlightError enum (ipaNotFound, uploadFailed, validationFailed, processingTimeout, groupNotFound)
- [x] Ensure all models conform to Sendable and Codable
- [x] Write unit tests for models

### 1.2 ChunkedUploader

- [x] Create ChunkedUploader actor
- [x] Implement chunk calculation (50MB default chunk size)
- [x] Implement reserveUploadFile for each chunk
- [x] Implement direct S3 upload with proper headers
- [x] Implement commitUploadFile after each chunk
- [x] Add UploadProgress struct with bytesUploaded, totalBytes, percentage
- [x] Add progress callback support
- [x] Implement retry logic with exponential backoff (3 retries)
- [x] Write unit tests with mock HTTP responses

### 1.3 AppStoreConnectAPI Extension

Extend existing AppStoreConnectAPI in SwiftlaneMatch:

- [x] Add createBuildUpload(appId:) -> BuildUpload
- [x] Add reserveBuildUploadFile(buildUploadId:, chunk:) -> FileReservation
- [x] Add commitBuildUploadFile(fileId:)
- [x] Add completeBuildUpload(buildUploadId:)
- [x] Add listBuilds(appId:, limit:) -> [Build]
- [x] Add getBuild(id:) -> Build
- [x] Add listBetaGroups(appId:) -> [BetaGroup]
- [x] Add addBuildToGroup(buildId:, groupId:)
- [x] Add setBetaTestInfo(buildId:, locale:, whatsNew:)
- [x] Add rate limiting handling with Retry-After header
- [x] Write unit tests with JSON fixtures

### 1.4 TestFlightService

- [x] Create TestFlightService actor
- [x] Implement uploadIPA(path:, appId:) using ChunkedUploader
- [x] Add IPA file validation (exists, is file)
- [x] Implement waitForProcessing with polling (30s interval, 30min timeout)
- [x] Implement distribute(buildId:, groups:, whatsNew:)
- [x] Implement findGroupByName(appId:, name:) helper
- [x] Add progress logging
- [x] Add artifact discovery from previous gym action
- [x] Write unit tests

### 1.5 DSL Action

- [x] Create PilotAction implementing Action protocol
- [x] Add PilotOptions struct (ipa, appId, changelog, groups, skipWaitingForProcessing)
- [x] Implement pilot() DSL function in SwiftlaneDSL
- [x] Add uploadToTestFlight() alias for pilot()
- [x] Register pilot in built-in-actions
- [x] Write unit tests for action

### 1.6 CLI Command

- [x] Create UploadTestFlightCommand
- [x] Add options: --ipa (required), --app-id, --changelog, --groups, --skip-waiting
- [x] Add progress display during upload
- [x] Add success message with build version
- [x] Add platform availability check (macOS only error message)
- [x] Register under `swiftlane upload testflight`
- [x] Write CLI integration tests

### 1.7 Testing & Integration

- [x] Create test fixtures for Build Upload API responses
- [x] Create test fixtures for Builds API responses
- [x] Create test fixtures for Beta Groups API responses
- [x] Write end-to-end test with mock services
- [x] Update CLAUDE.md with new module documentation

---

## Dependencies Graph

```
1.1 (Models)
    │
    ├──► 1.2 (ChunkedUploader)
    │        │
    │        └──► 1.4 (TestFlightService)
    │
    └──► 1.3 (API Extension)
             │
             └──► 1.4 (TestFlightService)
                      │
                      ├──► 1.5 (DSL Action)
                      │
                      └──► 1.6 (CLI Command)

1.4 + 1.5 + 1.6 ──► 1.7 (Testing)
```

### Parallelizable Work

- 1.2 (ChunkedUploader) + 1.3 (API Extension) can run in parallel after 1.1
- 1.5 (DSL Action) + 1.6 (CLI Command) can run in parallel after 1.4

---

## Validation Checklist

- [x] `swift build` succeeds
- [x] `swift test` passes all tests
- [x] pilot() action works in lane
- [x] `swiftlane upload testflight --help` shows options
- [x] Upload progress displays correctly
- [x] Rate limiting handled gracefully
- [x] Linux build succeeds with platform stubs
