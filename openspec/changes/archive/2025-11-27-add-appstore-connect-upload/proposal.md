# Proposal: add-appstore-connect-upload

## Summary

Add App Store Connect integration for uploading builds to TestFlight and basic build management. This implements Phase 4 from IMPLEMENTATION_PLAN.md using modern Build Upload API v4.1+.

## Why

iOS developers need to upload builds to TestFlight for beta testing. Fastlane's approach relies on private Apple APIs (Spaceship) that break frequently, has 2FA/authentication issues, and requires Ruby. Laner already has `AppStoreConnectAPI` for certificates/profiles but lacks build upload and TestFlight distribution.

## What Changes

### appstore-connect-upload

<!-- DELTA:ADDED -->
- [+] ChunkedUploader actor for Build Upload API v4.1+ with 50MB chunks
- [+] TestFlightService actor for upload orchestration and beta distribution
- [+] Build, BuildUpload, BetaGroup, TestFlightError models
- [+] AppStoreConnectAPI extensions for builds and beta groups
- [+] pilot() and uploadToTestFlight() DSL actions
- [+] `laner upload testflight` CLI command
<!-- /DELTA -->

## Problem Statement

iOS developers need to upload builds to TestFlight for beta testing. Currently:

1. **Fastlane's problems**:
   - Relies on private Apple APIs (Spaceship) that break frequently
   - 2FA/authentication issues require workarounds
   - Ruby dependency adds complexity

2. **Current Laner state**:
   - Has `AppStoreConnectAPI` in Match module (certificates/profiles/devices)
   - Has `JWTGenerator` for API authentication
   - Missing: build upload, TestFlight distribution

## Proposed Solution

Implement App Store Connect upload using **modern Build Upload API v4.1+**:

1. **Extend LanerMatch** with build upload capabilities (reuse existing API client)
2. **Build upload** via Build Upload API v4.1+ (chunked uploads, direct S3 upload)
3. **pilot() DSL action** - upload to TestFlight
4. **CLI command** - `laner upload testflight`

### Key Design Decisions

```toon
decisions[4]{decision,choice,rationale}:
  Upload method,Build Upload API v4.1+,Modern REST API; chunked uploads; cross-platform; no external tools
  Module,Extend LanerMatch,Reuse existing JWTGenerator and API client
  Auth,API Key only,No 2FA issues; CI-friendly; already implemented
  Scope,Upload + basic management,Minimal viable feature per IMPLEMENTATION_PLAN
```

## Scope

### In Scope (MVP)

```toon
mvp_scope[6]{feature,description}:
  IPA upload,Chunked upload via Build Upload API v4.1+
  Build list,List builds for app via API
  Build status,Get processing state
  TestFlight distribution,Add build to beta groups
  pilot() action,DSL action for TestFlight upload
  CLI upload,laner upload testflight command
```

### Out of Scope (Future)

- App Store submission (deliver)
- Metadata management (screenshots, descriptions)
- Customer reviews
- In-app purchases
- Phased release management

See `openspec/proposals/future-appstore-connect-full.md` for extended roadmap.

## Dependencies

```toon
dependencies[2]{module,reason}:
  LanerMatch,Reuse JWTGenerator and AppStoreConnectAPI
  LanerDSL,Action protocol for pilot()
```

## Success Criteria

1. Upload IPA to TestFlight via `laner upload testflight`
2. Zero 2FA/authentication issues on CI
3. pilot() action works in lanes
4. Compatible with existing Match workflow
5. Works on both macOS and Linux

## Risks

```toon
risks[2]{risk,mitigation}:
  API changes,Follow Apple's versioned API; abstract behind protocol
  Rate limiting,Implement exponential backoff with Retry-After header
```
