# Proposal: add-lane-execution

## Summary

Add the ability to execute custom lanes from pure Swift manifests (`Swiftlanefile.swift`) through CLI. Inspired by Tuist's approach, this provides full type-safety, IDE autocomplete, and reusable helpers while compiling manifests at runtime.

## Current State

```toon
implemented[6]{component,status}:
  ShellExecutor,complete
  XcodebuildExecutor,complete
  CLI commands (build/test/doctor/version),complete
  Lane struct,complete
  Action protocol,complete
  ExecutionContext,complete
```

```toon
missing[6]{component,impact}:
  LaneBuilder result builder,cannot define lanes declaratively
  Swiftlanefile manifest type,no root configuration type
  ManifestCompiler,cannot compile user Swift files
  Lane execution CLI command,cannot run custom lanes
  Built-in actions (gym/scan),must use raw shell commands
  Init/Edit commands,poor onboarding experience
```

## Problem Statement

Users cannot currently:
1. Run custom lanes defined in Swift
2. Get IDE autocompletion when writing lane definitions
3. Reuse code across lane definitions (helpers)
4. List available lanes in a project

The foundation is complete but the user-facing workflow is not connected.

## Proposed Solution (Tuist-inspired)

Use **pure Swift manifests** compiled at runtime:

```swift
// Swiftlane/Swiftlanefile.swift
import SwiftlaneDSL

let swiftlane = Swiftlanefile(
    lanes: [
        Lane("build") {
            gym(scheme: "App", configuration: .debug)
        },
        Lane("test") {
            scan(scheme: "AppTests", codeCoverage: true)
        }
    ]
)
```

**Key benefits:**
- Full type-safety (compile-time validation)
- IDE autocomplete via SwiftlaneDSL module
- Reusable helpers (`SwiftlaneHelpers/`)
- Familiar pattern for Tuist/SPM users

## Scope

```toon
in_scope[8]{item}:
  LaneBuilder result builder
  Swiftlanefile manifest type
  ManifestCompiler (swift build + run)
  ManifestCache (hash-based caching)
  swiftlane lane <name> command
  swiftlane lanes command
  swiftlane init command
  gym()/scan()/archive() action functions
```

```toon
out_of_scope[4]{item}:
  Match/code signing (Phase 3)
  App Store Connect (Phase 4)
  Plugin system (deferred)
  swiftlane edit command (nice-to-have)
```

## Success Criteria

1. `swiftlane init` creates `Swiftlane/Swiftlanefile.swift` template
2. Users can define lanes with result builders and get autocomplete
3. `swiftlane lanes` lists all available lanes
4. `swiftlane lane <name>` compiles manifest and executes lane
5. Subsequent runs use cached compilation (fast)
6. Built-in gym/scan/archive actions work

## Risks

```toon
risks[3]{risk,mitigation}:
  Cold start compilation time (~2-3s),Aggressive caching with hash invalidation
  Swift toolchain requirement,Clear error messages with installation guide
  Compilation errors hard to debug,Forward compiler errors with file:line info
```

## Timeline Impact

This completes Phase 2 of IMPLEMENTATION_PLAN.md and is prerequisite for all subsequent phases.
