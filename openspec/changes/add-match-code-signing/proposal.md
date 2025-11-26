# Change: Add Match Code Signing Capability

## Why

Code signing is the most error-prone and time-consuming part of iOS CI/CD. Teams struggle with:
- Multiple certificates/profiles per developer causing conflicts
- Manual renewal of expired credentials
- Onboarding new team members to signing infrastructure
- Secure storage and sharing of signing credentials

Fastlane Match solves this by storing encrypted certificates in Git/cloud storage. Laner needs equivalent functionality to be a complete Fastlane replacement.

## What Changes

- **NEW** `match` capability (LanerMatch module) — full Match alternative
- **NEW** Git-based encrypted storage for certificates and provisioning profiles
- **NEW** Keychain integration for certificate installation (macOS only)
- **NEW** App Store Connect API integration for certificate/profile management
- **NEW** CLI commands: `laner match sync`, `laner match nuke`
- **NEW** DSL action: `match(type:readonly:)` for lane usage
- **NEW** Device registration flow via App Store Connect API

## Impact

- Affected specs: `cli-commands`, `built-in-actions`
- New spec: `match`
- Affected code:
  - New module: `LanerMatch/` (or `Plugins/LanerMatch/`)
  - New files: `MatchService.swift`, `CryptoService.swift`, `KeychainService.swift`, `GitRepository.swift`, `AppStoreConnectAPI.swift`
  - CLI additions: `MatchCommand.swift`
  - DSL additions: `MatchAction.swift`

## Key Design Decisions

1. **Storage Backend**: Git-only initially (most common use case). S3/GCS can be added later via `StorageProvider` protocol.

2. **Encryption**: AES-256-GCM (same as Fastlane Match for compatibility). Use `swift-crypto` for cross-platform support.

3. **Keychain Access**: macOS-only via Security.framework. Linux builds will skip Keychain installation.

4. **App Store Connect API**: JWT authentication using `.p8` key file. Required for automated certificate/profile creation.

5. **Fastlane Match Compatibility**: Encrypted files should be readable by Fastlane Match (same encryption algorithm and file structure).

## Migration Path

Users with existing Fastlane Match repositories can use them directly with Laner — same encryption password works.

## Non-Goals (Phase 1)

- Google Cloud Storage / Amazon S3 backends
- Enterprise certificate support
- Push certificate management
- macOS certificate types (Developer ID)
