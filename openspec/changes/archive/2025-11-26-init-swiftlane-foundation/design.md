# Design: Swiftlane Foundation

## Context
We're building a Swift-native replacement for Fastlane. The foundation must:
- Use Swift 6 (swift-tools-version: 6.0) with default concurrency model
- Be modular for future plugin development
- Handle async process execution safely
- Parse xcodebuild output for meaningful feedback

**Note:** We use Swift 6 default concurrency. No `StrictConcurrency` flag is required — Swift 6 has concurrency checking enabled by default.

## Goals / Non-Goals

**Goals:**
- Establish clean module boundaries
- Provide type-safe async shell execution
- Support streaming output for long-running processes
- Basic CLI with build/test commands
- Minimal but functional DSL infrastructure

**Non-Goals:**
- Full DSL with result builders (Phase 2)
- Code signing / Match (Phase 3)
- Upload capabilities (Phase 4-5)
- Notifications (Phase 6)

## Decisions

### 1. Module Structure

```
swiftlane (executable)
    └── SwiftlaneCore (internal implementation)
            ├── SwiftlaneDSL (public DSL API)
            │       └── SwiftlaneKit (shared utilities)
            └── SwiftlaneKit
```

**Rationale:** Clear separation between public API (DSL) and internal implementation (Core). Kit module provides shared utilities without circular dependencies.

### 2. ShellExecutor as Actor

```swift
public actor ShellExecutor {
    public func run(_ command: String, arguments: [String]) async throws -> ProcessResult
    public func stream(_ command: String, arguments: [String]) -> AsyncThrowingStream<String, Error>
}
```

**Rationale:** Actor provides thread-safe state management for process tracking. `AsyncThrowingStream` enables real-time output processing.

**Alternative considered:** Class with locks — rejected due to complexity. Actor is the natural Swift 6 choice for stateful async services.

### 3. ProcessResult as Sendable Struct

```swift
public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let duration: Duration
}
```

**Rationale:** Immutable struct is naturally Sendable, can cross actor boundaries safely.

### 4. Platform Abstraction

```swift
#if os(macOS)
// Xcodebuild, Keychain operations
#else
// Stub with clear error messages
#endif
```

**Rationale:** Clean compile-time separation. Linux builds won't include xcodebuild code at all.

### 5. Logging Strategy

```swift
import Logging

public enum LogCategory: String {
    case shell, xcodebuild, cli, dsl
}

extension Logger {
    public static func swiftlane(_ category: LogCategory) -> Logger
}
```

**Rationale:** Category-based logging allows filtering by subsystem. Uses swift-log for backend flexibility.

## Swift 6 Concurrency

Swift 6 has data-race safety enabled by default. We follow these guidelines:

### When to Use Actors
Use actors only when you have **mutable state that needs isolation**:
- `ShellExecutor` — tracks running processes
- `ExecutionContext` — holds mutable artifact store

### When Structs Are Sufficient
Use plain structs for stateless or immutable types:
- `ProcessResult` — immutable result data
- `BuildOptions`, `TestOptions` — configuration passed to functions
- `XcodebuildExecutor` — stateless, just wraps shell calls

### Action Protocol Design

```swift
public protocol Action {
    associatedtype Options: Codable
    associatedtype Result

    static var name: String { get }
    func execute(context: ExecutionContext) async throws -> Result
}
```

**Note:** No explicit `Sendable` requirement. Swift 6 compiler will enforce data-race safety where needed.

### ExecutionContext

```swift
public actor ExecutionContext {
    public let environment: Environment
    public let logger: Logger
    public nonisolated let fileManager: FileManager

    private let _shell: ShellExecutor
    public var shell: ShellExecutor { _shell }

    private var _artifacts: ArtifactStore
    public func addArtifact(_ artifact: Artifact) { ... }
}
```

**Rationale:** Context holds mutable state (artifacts). Actor isolation prevents races.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Process execution complexity | Well-tested Foundation.Process wrapper |
| xcodebuild output parsing fragile | Structured tests with real output fixtures |
| Actor overhead for simple operations | Use actors only where needed, profile later |

## Migration Plan

N/A — greenfield project.

## Open Questions

1. **Should `XcodebuildExecutor` be an actor or stateless struct?**
   - Current decision: Stateless struct using `ShellExecutor` actor
   - Rationale: No state to protect, simpler API

2. **Result builder DSL in Phase 1 or Phase 2?**
   - Decision: Phase 2 — keep foundation minimal
   - Phase 1 has basic `Lane` struct, Phase 2 adds `@LaneBuilder`
