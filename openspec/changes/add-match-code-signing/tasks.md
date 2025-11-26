# Tasks: Add Match Code Signing

## Dependency Graph

```
[1.Foundation] ──┬──> [2.Crypto] ──────────────────┐
                 ├──> [3.GitStorage] ──────────────┤
                 ├──> [4.Keychain] ────────────────┼──> [6.MatchService] ──> [7.CLI] ──> [9.Docs]
                 └──> [5.AppStoreAPI] ─────────────┤                    └──> [8.DSL] ──┘
                                                   │                              │
                                                   └──────────────────────────────┴──> [10.Validation]
```

## 1. Foundation

- [x] 1.1 Create SwiftlaneMatch module in Package.swift
- [x] 1.2 Add swift-crypto dependency
- [x] 1.3 Add async-http-client dependency
- [x] 1.4 Define CertificateType enum (development/distribution/adhoc/appstore)
- [x] 1.5 Define Certificate and ProvisioningProfile models

## 2. Crypto Service

- [x] 2.1 Implement CryptoService with AES-256-GCM encryption
- [x] 2.2 Implement PBKDF2-HMAC-SHA256 key derivation
- [x] 2.3 Test encryption compatibility with Fastlane Match format
- [x] 2.4 Write unit tests for encrypt/decrypt roundtrip
- [x] 2.5 Write tests for decrypting real Fastlane Match files (FastlaneMatchCompatibilityTests)

## 3. Git Storage

- [x] 3.1 Define StorageProvider protocol
- [x] 3.2 Implement GitStorage with clone/pull/push
- [x] 3.3 Support SSH key authentication
- [x] 3.4 Support basic auth (token) authentication
- [x] 3.5 Implement shallow clone for efficiency
- [x] 3.6 Write unit tests for Git operations (mock)

## 4. Keychain Service (macOS)

- [x] 4.1 Implement KeychainService using Security.framework
- [x] 4.2 Implement certificate installation (import .p12)
- [x] 4.3 Implement temporary keychain creation for CI
- [x] 4.4 Implement keychain search list management
- [x] 4.5 Implement provisioning profile installation
- [x] 4.6 Add platform guard for Linux (#if os(macOS))
- [x] 4.7 Write integration tests for Keychain operations

## 5. App Store Connect API

- [x] 5.1 Implement JWT token generation (ES256 signature)
- [x] 5.2 Implement AppStoreConnectAPI client base
- [x] 5.3 Implement listCertificates endpoint
- [x] 5.4 Implement createCertificate endpoint
- [x] 5.5 Implement revokeCertificate endpoint
- [x] 5.6 Implement listProfiles endpoint
- [x] 5.7 Implement createProfile endpoint
- [x] 5.8 Implement deleteProfile endpoint
- [x] 5.9 Implement listDevices endpoint
- [x] 5.10 Implement registerDevice endpoint
- [x] 5.11 Write mock server tests for API client

## 6. Match Service

- [x] 6.1 Implement MatchService orchestrator
- [x] 6.2 Implement sync operation flow
- [x] 6.3 Implement nuke operation flow
- [x] 6.4 Implement register (devices) operation
- [x] 6.5 Implement changePassword operation
- [x] 6.6 Handle readonly mode logic
- [x] 6.7 Handle forceForNewDevices logic
- [x] 6.8 Write integration tests for MatchService (MatchServiceTests.swift - 19 tests)

## 7. CLI Commands

- [x] 7.1 Create MatchCommand command group
- [x] 7.2 Implement match init subcommand
- [x] 7.3 Implement match sync subcommand with options
- [x] 7.4 Implement match nuke subcommand with confirmation
- [x] 7.5 Implement match register subcommand
- [x] 7.6 Implement match change-password subcommand
- [x] 7.7 Add environment variable support (MATCH_PASSWORD etc.)
- [x] 7.8 Write CLI tests (MatchCommandTests.swift - comprehensive CLI tests)

## 8. DSL Actions

- [x] 8.1 Create MatchAction conforming to Action protocol
- [x] 8.2 Create MatchOptions struct
- [x] 8.3 Create RegisterDevicesAction
- [x] 8.4 Create RegisterDevicesOptions struct
- [x] 8.5 Add match() DSL function
- [x] 8.6 Add registerDevices() DSL function
- [x] 8.7 Write DSL action tests

## 9. Documentation

- [x] 9.1 Add match command to CLI help
- [x] 9.2 Update CLAUDE.md with match module
- [x] 9.3 Create example MatchConfig.swift (included in README.md DSL Example)
- [x] 9.4 Document environment variables (README.md Environment Variables section)

## 10. Validation

- [ ] 10.1 Test against real Fastlane Match repository (requires actual Match repo)
- [ ] 10.2 Test sync/nuke/register flow end-to-end (requires actual Match repo)
- [ ] 10.3 Test CI scenario with temporary keychain (requires CI environment)
- [x] 10.4 Run full test suite (309 tests passing)
- [x] 10.5 Update openspec specs after implementation

## Parallelization Notes

```toon
parallel_groups[4]{group,tasks,note}:
  Foundation,1.x,Must complete first
  Core Services,2.x;3.x;4.x;5.x,Can run in parallel after Foundation
  Orchestration,6.x;7.x;8.x,Requires Core Services
  Finalization,9.x;10.x,Sequential after Orchestration
```
