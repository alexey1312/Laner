<!-- OPENSPEC:START -->

# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:

- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:

- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# Laner

Swift-based CI/CD pipeline automation framework.

## Project Structure

```toon
modules[6]{name,description}:
  laner,CLI executable
  LanerCore,Internal implementation (commands, orchestration)
  LanerDSL,Public DSL API for pipeline definitions
  LanerKit,Shared utilities and types
  LanerPluginKit,Plugin development kit
  LanerMatch,Code signing and TestFlight upload (Match-compatible)
```

## Dependencies

```toon
dependencies[4]{package,purpose}:
  swift-argument-parser,CLI parsing
  swift-log,Logging
  swift-crypto,AES-256-GCM encryption for Match
  async-http-client,App Store Connect API requests
```

## Platform

macOS 13+, Swift 6.0

## Maintaining This Document

Keep `CLAUDE.md` up-to-date when making significant changes:

- Add new modules or major components
- Update architecture patterns
- Change key dependencies
- Add important conventions

## Maintaining Bilingual Instructions

Usage instructions exist in two separate files:

- `docs/USAGE.md` — English version
- `docs/USAGE_RU.md` — Russian version

When updating documentation:

- **Keep both files in sync** — update `USAGE.md` and `USAGE_RU.md` together
- Update command examples in both files
- Add new features to both instruction sets
- Ensure troubleshooting sections match in both files

Note: Russian text should only exist in `docs/USAGE_RU.md`. All other documentation (README.md, other docs/, CLAUDE.md, code comments) must be in English only.

## ROADMAP Maintenance

When completing tasks from `ROADMAP.md`:

- Mark completed items with checkboxes or move to "Completed" section
- Update progress indicators if present
- Add completion dates where appropriate
- Remove or update any outdated items

### TOON Format Convention

Use TOON (Token-Oriented Object Notation) for all tabular data. TOON reduces token usage by 30-60% by declaring fields once in array headers.

```toon
format:
  syntax: name[count]{field1,field2,...}:
  indent: 2 spaces for rows
  delimiter: comma between values

example[2]{id,name,status}:
  1,Build command,active
  2,Test command,active
```

When adding lists of items (modules, commands, files, etc.), always use TOON tables instead of markdown lists.

**Exception:** OpenSpec `tasks.md` — task items MUST use markdown checklists (`- [ ]`) for openspec parsing. Other content in tasks.md (summaries, notes, dependency graphs) can use TOON.

## Architecture

```
laner (CLI executable)
    ↓
LanerCore (Commands & Orchestration) - internal
    ↓
LanerDSL (Public DSL API) + LanerKit (Shared Utilities)
    ↓
LanerPluginKit (Plugin Development)
```

### Key Source Files

```toon
sources[15]{path,description}:
  Sources/laner/main.swift,CLI entry with ArgumentParser
  Sources/LanerCore/Commands/,Build, Test, Doctor, Version, Init, Lane, Lanes, Match, Upload commands
  Sources/LanerCore/Manifest/,ManifestCompiler, ManifestCache, ManifestLoader
  Sources/LanerDSL/Lane.swift,Lane definition and execution
  Sources/LanerDSL/Action.swift,Action protocol
  Sources/LanerDSL/ExecutionContext.swift,@MainActor execution environment
  Sources/LanerDSL/Builders/LaneBuilder.swift,Result builder for declarative lane DSL
  Sources/LanerDSL/Manifest/Lanerfile.swift,Root manifest type
  Sources/LanerDSL/Actions/Functions.swift,"gym(), scan(), archive() DSL functions"
  Sources/LanerDSL/Actions/PilotAction.swift,"pilot(), uploadToTestFlight() DSL functions"
  Sources/LanerKit/ShellExecutor.swift,Actor for shell commands
  Sources/LanerKit/Xcodebuild/,xcodebuild wrapper types
  Sources/LanerMatch/Services/TestFlightService.swift,TestFlight upload and distribution
  Sources/LanerMatch/Services/ChunkedUploader.swift,Build Upload API v4.1+ chunked uploads
  Sources/LanerMatch/API/AppStoreConnectAPI+Builds.swift,Build and beta group API extensions
```

## Concurrency Model

```toon
actors[11]{type,description}:
  ShellExecutor,Actor for thread-safe command execution
  ExecutionContext,@MainActor for isolated execution environment
  ArtifactStore,Actor for thread-safe artifact management
  ManifestCompiler,Actor for thread-safe manifest compilation
  CryptoService,Actor for AES-256-GCM encryption
  GitStorage,Actor for Git repository operations
  KeychainService,Actor for macOS Keychain operations
  MatchService,Actor for Match code signing operations
  AppStoreConnectAPI,Actor for App Store Connect API
  ChunkedUploader,Actor for chunked file uploads to S3
  TestFlightService,Actor for TestFlight operations
```

All public types conform to `Sendable`.

## Build & Test

```bash
swift build
swift test
swift test --enable-code-coverage
```

## CLI Commands

```toon
commands[9]{name,description}:
  version,Show version info
  doctor,Check environment (Swift, Git, Xcode, etc.)
  init,Initialize Laner project (creates Lanerfile.swift)
  lanes,List available lanes from manifest
  lane <name>,Execute a lane by name
  build,Build iOS/macOS project
  test,Run tests
  match,Code signing management (sync, nuke, register, change-password)
  upload testflight,Upload IPA to TestFlight
```

## Code Conventions

```toon
conventions[6]{pattern,usage}:
  Actor-based concurrency,I/O operations
  Protocol-driven design,Action and LanerConfiguration protocols
  Type erasure,AnyAction for heterogeneous collections
  Result builders,LaneBuilder for declarative DSL
  Builder pattern,Context modifications
  Re-export dependencies,@_exported import
```

## Cross-Platform Considerations

This project builds on both macOS and Linux (CI). Key rules:

```toon
platform_rules[4]{rule,reason}:
  No CommonCrypto imports,CommonCrypto is macOS-only; use swift-crypto instead
  No Security.framework for crypto,SecRandomCopyBytes unavailable on Linux; use SymmetricKey for random
  Use HKDF not PBKDF2,swift-crypto HKDF is cross-platform; PBKDF2 requires CommonCrypto
  Wrap macOS-only code,Use #if os(macOS) for Keychain and Security framework APIs
```

### Cryptography (LanerMatch)

CryptoService uses **swift-crypto** exclusively for cross-platform support:

- Key derivation: `HKDF<SHA256>.deriveKey()`
- Encryption: `AES.GCM.seal()` / `AES.GCM.open()`
- Random bytes: `SymmetricKey(size:)` generates secure random data
- File format: `[salt:16][nonce:12][ciphertext][tag:16]`

**Never use:** `CommonCrypto`, `CCKeyDerivationPBKDF`, `SecRandomCopyBytes` in shared code.

## Tests

```toon
test_suites[4]{directory,coverage}:
  LanerKitTests/,Shell, Xcodebuild, Logging, Platform tests
  LanerDSLTests/,DSL functionality tests
  LanerCoreTests/,CLI command tests
  LanerMatchTests/,Crypto, API, Keychain tests
```

Uses Swift Testing framework (`@Suite`, `@Test` macros).

## External Documentation

### Apple Developer Documentation

Apple docs require JavaScript rendering. Use **Sosumi.ai** proxy for AI-readable markdown:

```
https://sosumi.ai/documentation/{path}
```

```toon
useful_docs[6]{topic,url}:
  App Store Connect API,https://sosumi.ai/documentation/appstoreconnectapi
  Build Uploads,https://sosumi.ai/documentation/appstoreconnectapi/build-uploads
  Builds,https://sosumi.ai/documentation/appstoreconnectapi/builds
  Beta Groups,https://sosumi.ai/documentation/appstoreconnectapi/beta-groups
  Beta Testers,https://sosumi.ai/documentation/appstoreconnectapi/beta-testers
  App Store Versions,https://sosumi.ai/documentation/appstoreconnectapi/app-store-versions
```

Replace `developer.apple.com` → `sosumi.ai` in any Apple doc URL to get markdown.
