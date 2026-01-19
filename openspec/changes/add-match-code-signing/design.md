# Design: Match Code Signing

## Context

Code signing management is critical for iOS app distribution. Fastlane Match pioneered the "shared identity" approach where one certificate is shared across the team via encrypted Git storage. Laner needs this capability to replace Fastlane.

**Stakeholders**: iOS developers, CI/CD pipelines, DevOps teams

**Constraints**:

- Must be compatible with existing Fastlane Match repositories
- Must work on macOS CI runners (GitHub Actions, CircleCI, etc.)
- Must support App Store Connect API (JWT auth)
- Security.framework available only on macOS

## Goals / Non-Goals

**Goals**:

- Sync certificates and provisioning profiles from Git storage
- Create new certificates via App Store Connect API when needed
- Install certificates to Keychain on macOS
- Support readonly mode for CI pipelines
- Revoke and regenerate credentials (nuke operation)
- Register new devices

**Non-Goals** (Phase 1):

- Google Cloud Storage / Amazon S3 support
- Enterprise certificates
- Push certificates
- Mac Developer ID certificates
- Cross-platform Keychain (Linux has no Keychain)

## Architecture

### Module Structure

```
LanerMatch/
├── MatchService.swift           # Main orchestrator
├── Storage/
│   ├── StorageProvider.swift    # Protocol for storage backends
│   └── GitStorage.swift         # Git repository storage
├── Crypto/
│   └── CryptoService.swift      # AES-256-GCM encryption
├── Keychain/
│   └── KeychainService.swift    # macOS Keychain operations
├── API/
│   ├── AppStoreConnectAPI.swift # ASC REST API client
│   └── JWTGenerator.swift       # JWT token generation
├── Models/
│   ├── Certificate.swift        # Certificate model
│   ├── ProvisioningProfile.swift
│   ├── CertificateType.swift    # .development, .distribution
│   └── Device.swift
└── Actions/
    └── MatchAction.swift        # DSL action wrapper
```

### Data Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Git Storage   │────▶│  CryptoService   │────▶│ KeychainService │
│ (encrypted .cer,│     │ (AES-256-GCM     │     │ (install to     │
│  .p12, .mobile- │     │  decrypt)        │     │  macOS Keychain)│
│  provision)     │                              │                 │
└─────────────────┘                              └─────────────────┘
        │
        │ (if not found)
        ▼
┌─────────────────┐     ┌──────────────────┐
│ AppStoreConnect │────▶│   CryptoService  │
│      API        │     │   (encrypt +     │
│ (create cert/   │     │    store)        │
│  profile)       │                        │
└─────────────────┘                        │
                                           ▼
                                   Git commit & push
```

### Storage Structure (Fastlane Match Compatible)

```
certificates-repo/
├── certs/
│   ├── development/
│   │   ├── <cert_id>.cer      # Encrypted certificate
│   │   └── <cert_id>.p12      # Encrypted private key
│   └── distribution/
│       ├── <cert_id>.cer
│       └── <cert_id>.p12
├── profiles/
│   ├── development/
│   │   └── Development_<app_id>.mobileprovision
│   ├── adhoc/
│   │   └── AdHoc_<app_id>.mobileprovision
│   └── appstore/
│       └── AppStore_<app_id>.mobileprovision
└── match_version.txt
```

## Decisions

### D1: Encryption Algorithm — AES-256-GCM

**Decision**: Use AES-256-GCM with password-based key derivation (same as Fastlane Match).

**Rationale**:

- Compatibility with existing Match repositories
- Standard algorithm supported by swift-crypto
- GCM provides authentication (AEAD)

**Implementation**:

```swift
// Key derivation: PBKDF2-HMAC-SHA256 (10,000 iterations, 32-byte key)
// Encryption: AES-256-GCM
// File format: base64(salt + nonce + ciphertext + tag)
```

### D2: Storage Backend — Git-Only Initially

**Decision**: Support only Git storage in Phase 1.

**Rationale**:

- Most common use case (90%+ of Fastlane Match users)
- Simplest to implement and test
- Protocol-based design allows adding S3/GCS later

**Protocol**:

```swift
protocol StorageProvider: Sendable {
    func download(to directory: URL) async throws
    func upload(files: [URL], message: String) async throws
    func exists(path: String) async throws -> Bool
}
```

### D3: Keychain Strategy — Temporary Keychain

**Decision**: Create temporary Keychain for CI, use login Keychain for local dev.

**Rationale**:

- CI should not pollute system Keychain
- Local dev benefits from persistent certificates
- Matches Fastlane Match behavior

**Implementation**:

```swift
struct KeychainService {
    func install(certificate: Certificate, keychain: Keychain) async throws
    func createTemporaryKeychain(name: String, password: String) async throws -> Keychain
    func setSearchList(_ keychains: [Keychain]) async throws
}
```

### D4: App Store Connect API — JWT Authentication

**Decision**: Use JWT tokens with `.p8` key files for API authentication.

**Rationale**:

- Apple's recommended approach for automation
- 20-minute token validity (regenerate as needed)
- No session cookies or 2FA issues

**Configuration**:

```swift
struct APICredentials: Codable {
    let keyId: String        // Key ID from App Store Connect
    let issuerId: String     // Issuer ID from App Store Connect
    let keyPath: String      // Path to .p8 file
}
```

### D5: Certificate Types — iOS Focus

**Decision**: Support only iOS certificate types initially.

| Type          | Certificate        | Provisioning Profile |
| ------------- | ------------------ | -------------------- |
| `development` | Apple Development  | iOS Development      |
| `adhoc`       | Apple Distribution | Ad Hoc               |
| `appstore`    | Apple Distribution | App Store            |

### D6: Readonly Mode Default in CI

**Decision**: Default to `readonly: true` in CI environments.

**Rationale**:

- Prevents accidental certificate regeneration in CI
- Matches Fastlane best practice
- CI should not modify Git repository

```swift
match(type: .appstore) // readonly: environment.isCI
match(type: .appstore, readonly: false) // explicit write mode
```

## Risks / Trade-offs

| Risk                                     | Mitigation                                        |
| ---------------------------------------- | ------------------------------------------------- |
| Encryption incompatibility with Fastlane | Test against real Match repositories              |
| App Store Connect API rate limits        | Cache responses, batch operations                 |
| Keychain access denied in CI             | Document CI setup (unlock keychain)               |
| Git auth failures in CI                  | Support multiple auth methods (SSH, token, basic) |
| Certificate creation failures            | Validate bundle ID exists before creating         |

## API Design

### CLI Commands

```bash
# Initialize match configuration
laner match init

# Sync certificates (download & install)
laner match sync --type development
laner match sync --type appstore --readonly

# Register devices
laner match register --devices devices.txt

# Revoke all certificates (dangerous!)
laner match nuke --type development
laner match nuke --type distribution

# Change repository password
laner match change-password
```

### DSL Action

```swift
Lane("release") {
    // Sync certificates before build
    match(type: .appstore)

    // Build with signing
    gym(scheme: "App", exportMethod: .appStore)
}

Lane("beta") {
    // Register new devices and regenerate profiles
    registerDevices(file: "devices.txt")
    match(type: .adhoc, forceForNewDevices: true)

    gym(scheme: "App", exportMethod: .adHoc)
}
```

### Configuration (Matchfile equivalent)

```swift
// Laner/MatchConfig.swift
let matchConfig = MatchConfiguration(
    gitURL: "git@github.com:team/certificates.git",
    appIdentifiers: ["com.example.app"],
    teamId: "TEAM123",
    username: "developer@example.com" // for ASC API
)
```

## Open Questions

1. **Should we support Matchfile parsing?** — Probably not worth it, users can migrate config.

2. **How to handle 2FA for Apple ID?** — Recommend API key (`.p8`) instead. App-specific passwords are deprecated.

3. **Should `match nuke` require double confirmation?** — Yes, destructive operation.

4. **How to test without real Apple Developer account?** — Mock API responses, test encryption separately.
