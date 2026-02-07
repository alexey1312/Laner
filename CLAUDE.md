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

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
dependencies[5]{package,purpose}:
  swift-argument-parser,CLI parsing
  swift-log,Logging
  swift-crypto,AES-256-GCM encryption for Match
  async-http-client,App Store Connect API requests
  pkl-swift,Pkl configuration language evaluator
```

## Platform

macOS 13+, Swift 6.0+

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
LanerCore (Commands & Orchestration) - internal, not a library product
    ↓
LanerDSL (Public DSL API) ──→ LanerMatch (Code Signing)
    ↓                              ↓
LanerKit (Shared Utilities) ◄──────┘
    ↓
LanerPluginKit (Plugin Development)
```

### API Surface & Re-exports

`LanerDSL` uses `@_exported import` to re-export `LanerKit` and `LanerMatch`. Users only need `import LanerDSL` to access the full public API. `LanerCore` is internal — it's only consumed by the `laner` executable, never exposed as a library product.

### Manifest Evaluation Flow

User manifests (`Laner/Lanerfile.pkl`) are **evaluated using the embedded Pkl runtime**, not compiled:

1. `ManifestLoader` discovers `Laner/Lanerfile.pkl`
2. `ManifestCache` checks SHA256 hash for change detection
3. Pkl evaluator loads and validates the `.pkl` file against the schema
4. Pkl output is decoded into `Lanerfile.Module` (generated Swift types)
5. `ActionDispatcher` maps Pkl action types to Swift `Action` implementations

This provides type-safe, validated configuration that evaluates in milliseconds with no compilation step.

### Key Source Files

```toon
sources[17]{path,description}:
  Sources/laner/main.swift,CLI entry with ArgumentParser
  Sources/LanerCore/Commands/,Build, Test, Doctor, Version, Init, Lane, Lanes, Match, Upload commands
  Sources/LanerCore/Manifest/,ManifestCache, ManifestLoader, ManifestError
  Sources/LanerDSL/Lane.swift,LaneRunner and LaneResult
  Sources/LanerDSL/Action.swift,Action protocol
  Sources/LanerDSL/ActionDispatcher.swift,Maps Pkl action types to Swift Action implementations
  Sources/LanerDSL/PklTypeConversions.swift,Pkl enum to Swift enum conversions
  Sources/LanerDSL/ExecutionContext.swift,@MainActor execution environment
  Sources/LanerDSL/Generated/Lanerfile.pkl.swift,Generated Swift types from Pkl schema
  Sources/LanerDSL/Resources/pkl/Lanerfile.pkl,Pkl schema definition
  Sources/LanerDSL/Manifest/Lanerfile.swift,Convenience extensions on Lanerfile.Module
  Sources/LanerDSL/Actions/Functions.swift,"GymAction, ScanAction, ArchiveAction implementations"
  Sources/LanerDSL/Actions/ShellActionImpl.swift,Shell command execution action
  Sources/LanerKit/ShellExecutor.swift,Actor for shell commands
  Sources/LanerKit/Xcodebuild/,xcodebuild wrapper types
  Sources/LanerMatch/Services/TestFlightService.swift,TestFlight upload and distribution
  Sources/LanerMatch/Services/ChunkedUploader.swift,Build Upload API v4.1+ chunked uploads
```

## Concurrency Model

```toon
actors[10]{type,description}:
  ShellExecutor,Actor for thread-safe command execution
  ExecutionContext,@MainActor for isolated execution environment
  ArtifactStore,Actor for thread-safe artifact management
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

Always use mise tasks (output is parsed by xcsift for token efficiency):

```bash
mise run build          # Debug build
mise run build:release  # Release build
mise run test           # Run tests
mise run lint           # SwiftLint + actionlint
mise run format         # Format all (Swift + Markdown)
mise run clean          # Clean build artifacts
```

### Running a Single Test

```bash
# Single test suite
swift test --filter LanerKitTests 2>&1 | xcsift -w -f toon --toon-key-folding safe

# Single test by name
swift test --filter LanerKitTests.ShellExecutorTests/runEchoCommand 2>&1 | xcsift -w -f toon --toon-key-folding safe
```

### Strict Mode

`LANER_STRICT=1 swift build` enables `-warnings-as-errors` for all targets except LanerMatch (excluded due to unavoidable SecKeychain deprecation warnings).

## CLI Commands

```toon
commands[9]{name,description}:
  version,Show version info
  doctor,Check environment (Swift, Git, Xcode, etc.)
  init,Initialize Laner project (creates Lanerfile.pkl)
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
  Protocol-driven design,Action protocol
  Pkl configuration,Declarative typed config via Lanerfile.pkl
  Action dispatching,ActionDispatcher maps Pkl actions to Swift implementations
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

Uses Swift Testing framework (`@Suite`, `@Test` macros). Tests are self-contained — no shared test utilities module; each test target uses `@testable import` directly.

## Git Hooks

Pre-commit and commit-msg hooks are configured in `.githooks/` and activated via `mise` (auto-set on directory enter). They run `hk` checks (formatting, linting, conventional commits). Set `HK=0` to bypass.

## Examples

`Examples/` contains reference Pkl manifests: `BasicLanerfile.pkl`, `FullPipeline.pkl`, `MatchConfig.pkl`. Use these as templates when implementing new actions.

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
