# Design: App Store Connect Upload (MVP)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLI Layer                                 │
│  laner upload testflight                                    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                     LanerCore                                │
│  UploadTestFlightCommand                                        │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                   LanerMatch (Extended)                      │
│  ┌─────────────────┐  ┌─────────────────┐                       │
│  │ChunkedUploader  │  │TestFlightService│                       │
│  └────────┬────────┘  └────────┬────────┘                       │
│           │                    │                                 │
│  ┌────────▼────────────────────▼────────────────────────────┐   │
│  │           AppStoreConnectAPI (existing + extended)        │   │
│  │  + Build Upload API v4.1+ (chunked uploads)              │   │
│  │  + listBuilds, getBuild, addBuildToGroup                 │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                     LanerDSL                                 │
│  pilot()                                                        │
└─────────────────────────────────────────────────────────────────┘
```

## Extended Files in LanerMatch

```
Sources/LanerMatch/
├── API/
│   ├── AppStoreConnectAPI.swift      # Existing - extend with builds
│   ├── AppStoreConnectAPI+Builds.swift # NEW - Build Upload API v4.1+
│   └── JWTGenerator.swift            # Existing - reuse
├── Services/
│   ├── ChunkedUploader.swift         # NEW - Chunked file upload
│   └── TestFlightService.swift       # NEW - TestFlight operations
├── Models/
│   ├── Build.swift                   # NEW - Build model
│   ├── BetaGroup.swift               # NEW - Beta group model
│   └── TestFlightError.swift         # NEW - Error types
└── ...existing files...
```

## Key Components

### 1. ChunkedUploader

Modern Build Upload API v4.1+ implementation with chunked uploads:

```swift
actor ChunkedUploader {
    private let api: AppStoreConnectAPI
    private let chunkSize: Int = 50 * 1024 * 1024 // 50MB

    func upload(
        ipaPath: String,
        appId: String,
        progress: @escaping (UploadProgress) -> Void
    ) async throws -> Build
}

struct UploadProgress: Sendable {
    let bytesUploaded: Int64
    let totalBytes: Int64
    var percentage: Double { Double(bytesUploaded) / Double(totalBytes) * 100 }
}
```

**Why Build Upload API v4.1+:**
- Modern REST API, no external tools required
- Chunked uploads for large files
- Direct S3 upload for performance
- Better error handling and progress tracking
- Cross-platform (works on Linux for API-only operations)

### 2. AppStoreConnectAPI Extensions

Extend existing API client for builds:

```swift
extension AppStoreConnectAPI {
    // Build Upload API v4.1+
    func createBuildUpload(appId: String) async throws -> BuildUpload
    func reserveBuildUploadFile(buildUploadId: String, chunk: ChunkInfo) async throws -> FileReservation
    func commitBuildUploadFile(fileId: String) async throws
    func completeBuildUpload(buildUploadId: String) async throws

    // Builds
    func listBuilds(appId: String, limit: Int) async throws -> [Build]
    func getBuild(id: String) async throws -> Build

    // TestFlight
    func listBetaGroups(appId: String) async throws -> [BetaGroup]
    func addBuildToBetaGroup(buildId: String, groupId: String) async throws
    func setBetaTestInfo(buildId: String, whatsNew: String) async throws
}
```

### 3. TestFlightService

Orchestrates TestFlight operations:

```swift
actor TestFlightService {
    private let api: AppStoreConnectAPI
    private let uploader: ChunkedUploader

    func upload(
        ipaPath: String,
        appId: String,
        progress: @escaping (UploadProgress) -> Void
    ) async throws -> Build

    func waitForProcessing(buildId: String) async throws -> Build

    func distribute(
        buildId: String,
        groups: [String],
        whatsNew: String?
    ) async throws
}
```

### 4. DSL Action

```swift
public func pilot(
    ipa: String? = nil,
    appId: String? = nil,
    changelog: String? = nil,
    groups: [String]? = nil,
    skipWaitingForProcessing: Bool = true
) -> AnyAction
```

## Upload Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Validate IPA                                              │
│    - Check file exists                                       │
│    - Check file is valid IPA                                │
└──────────────────────────┬──────────────────────────────────┘
                           │ success
┌──────────────────────────▼──────────────────────────────────┐
│ 2. Create Build Upload                                       │
│    - POST /v1/buildUploads                                  │
│    - Get buildUploadId                                      │
└──────────────────────────┬──────────────────────────────────┘
                           │ success
┌──────────────────────────▼──────────────────────────────────┐
│ 3. Upload Chunks                                             │
│    For each 50MB chunk:                                      │
│    - POST /v1/buildUploadFiles (reserve)                    │
│    - PUT to S3 URL (upload chunk)                           │
│    - POST /v1/buildUploadFiles/{id}/commit                  │
└──────────────────────────┬──────────────────────────────────┘
                           │ all chunks uploaded
┌──────────────────────────▼──────────────────────────────────┐
│ 4. Complete Upload                                           │
│    - POST /v1/buildUploads/{id}/complete                    │
└──────────────────────────┬──────────────────────────────────┘
                           │ success
┌──────────────────────────▼──────────────────────────────────┐
│ 5. Wait for Processing (optional)                            │
│    - Poll GET /v1/builds until processingState = VALID      │
└──────────────────────────┬──────────────────────────────────┘
                           │ success
┌──────────────────────────▼──────────────────────────────────┐
│ 6. Distribute to TestFlight                                  │
│    - Add to beta groups                                      │
│    - Set what-to-test notes                                  │
└─────────────────────────────────────────────────────────────┘
```

## CLI Command

```bash
laner upload testflight --ipa App.ipa
laner upload testflight --ipa App.ipa --groups "QA,Internal" --changelog "Bug fixes"
```

## Configuration

Reuses existing Match environment variables:
- APP_STORE_CONNECT_API_KEY_ID
- APP_STORE_CONNECT_API_ISSUER_ID
- APP_STORE_CONNECT_API_KEY_PATH

Plus optional:
- APP_STORE_APP_ID (for build queries)

## Error Handling

```swift
enum TestFlightError: LocalizedError {
    case ipaNotFound(String)
    case uploadFailed(String)
    case chunkUploadFailed(Int, String)
    case processingTimeout
    case groupNotFound(String)
    case rateLimited(retryAfter: Int)
}
```

## Testing Strategy

```toon
tests[3]{type,approach}:
  Unit,Mock API responses and chunk uploads
  Integration,End-to-end with test IPA
  Fixtures,Sample API JSON responses
```
