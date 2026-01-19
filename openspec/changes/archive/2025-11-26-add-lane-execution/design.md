# Design: add-lane-execution

## Overview

This design covers the architecture for lane execution from CLI, completing Phase 2 of the implementation plan. Inspired by Tuist's approach, we use **pure Swift manifests** compiled at runtime for full type-safety and IDE support.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     CLI Layer                            │
├─────────────────────────────────────────────────────────┤
│  laner lane <name>    │    laner lanes          │
│  laner init           │    laner edit           │
└─────────────┬─────────────┴──────────────┬──────────────┘
              │                            │
              ▼                            ▼
┌─────────────────────────────────────────────────────────┐
│                   LanerCore                          │
├─────────────────────────────────────────────────────────┤
│  LaneCommand              │    LanesCommand             │
│  ManifestLoader           │    InitCommand              │
│  ManifestCompiler         │    EditCommand              │
└─────────────┬─────────────┴─────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│                    LanerDSL                          │
├─────────────────────────────────────────────────────────┤
│  LaneBuilder              │    ActionBuilder            │
│  LanerConfiguration   │    Built-in Actions         │
│  LaneRunner               │    (GymAction, ScanAction)  │
└─────────────────────────────────────────────────────────┘
```

## Tuist-Inspired Manifest System

### Project Structure

```
MyProject/
├── Laner/
│   ├── Lanerfile.swift           # Main manifest
│   └── LanerHelpers/             # Reusable code (optional)
│       └── Lanes+Templates.swift
├── MyProject.xcworkspace
└── ...
```

### Manifest Example

```swift
// Laner/Lanerfile.swift
import LanerDSL

let laner = Lanerfile(
    lanes: [
        Lane("build") {
            gym(scheme: "App", configuration: .debug)
        },

        Lane("test") {
            scan(scheme: "AppTests", codeCoverage: true)
        },

        Lane("release") {
            gym(scheme: "App", configuration: .release)
            scan(scheme: "AppTests")
            archive(scheme: "App", exportMethod: .appStore)
        }
    ]
)
```

### Reusable Helpers

```swift
// Laner/LanerHelpers/Lanes+Templates.swift
import LanerDSL

extension Lane {
    public static func featureLane(name: String, scheme: String) -> Lane {
        Lane(name) {
            gym(scheme: scheme, configuration: .debug)
            scan(scheme: "\(scheme)Tests")
        }
    }
}
```

```swift
// Laner/Lanerfile.swift
import LanerDSL
import LanerHelpers

let laner = Lanerfile(
    lanes: [
        .featureLane(name: "build_search", scheme: "Search"),
        .featureLane(name: "build_home", scheme: "Home"),
    ]
)
```

## Component Design

### 1. ManifestCompiler

Compiles Swift manifest to executable and extracts configuration.

```swift
actor ManifestCompiler {
    /// Compiles Lanerfile.swift and returns configuration
    func compile(at path: URL) async throws -> CompiledManifest

    /// Caches compiled manifests for faster subsequent runs
    func cachedManifest(for path: URL) async throws -> CompiledManifest?

    /// Invalidates cache when source changes
    func invalidateCache(for path: URL) async
}

struct CompiledManifest: Sendable {
    let executablePath: URL
    let sourceHash: String
    let compiledAt: Date
}
```

### 2. Compilation Strategy

**How it works (Tuist-style):**

1. Find `Laner/Lanerfile.swift` in project root
2. Generate temporary Swift package with LanerDSL dependency
3. Compile manifest to executable using `swift build`
4. Run executable to extract JSON-serialized configuration
5. Cache compiled executable (invalidate on source change)

```swift
// Generated Package.swift for compilation
let package = Package(
    name: "LanerManifest",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "<laner-install-path>")
    ],
    targets: [
        .executableTarget(
            name: "LanerManifest",
            dependencies: [
                .product(name: "LanerDSL", package: "Laner")
            ],
            path: "."
        )
    ]
)
```

### 3. Manifest Execution

The compiled manifest outputs JSON configuration:

```swift
// Generated main.swift wrapper
import LanerDSL
import Foundation

// Include user's Lanerfile.swift content here

// Serialize and output
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let data = try encoder.encode(laner)
print(String(data: data, encoding: .utf8)!)
```

### 4. LaneBuilder (Result Builder)

```swift
@resultBuilder
public struct LaneBuilder {
    public static func buildBlock(_ components: AnyAction...) -> [AnyAction]
    public static func buildOptional(_ component: [AnyAction]?) -> [AnyAction]
    public static func buildEither(first: [AnyAction]) -> [AnyAction]
    public static func buildEither(second: [AnyAction]) -> [AnyAction]
    public static func buildArray(_ components: [[AnyAction]]) -> [AnyAction]
    public static func buildExpression(_ expression: AnyAction) -> [AnyAction]
}
```

### 5. Built-in Action Functions

DSL-style functions that create actions:

```swift
// LanerDSL/Actions/Functions.swift

/// Builds the project using xcodebuild
public func gym(
    scheme: String,
    workspace: String? = nil,
    project: String? = nil,
    configuration: BuildConfiguration = .debug,
    destination: String? = nil
) -> AnyAction {
    AnyAction(GymAction(options: .init(
        scheme: scheme,
        workspace: workspace,
        project: project,
        configuration: configuration,
        destination: destination
    )))
}

/// Runs tests using xcodebuild
public func scan(
    scheme: String,
    workspace: String? = nil,
    devices: [String]? = nil,
    codeCoverage: Bool = false
) -> AnyAction {
    AnyAction(ScanAction(options: .init(
        scheme: scheme,
        workspace: workspace,
        devices: devices,
        codeCoverage: codeCoverage
    )))
}

/// Creates an archive for distribution
public func archive(
    scheme: String,
    configuration: BuildConfiguration = .release,
    exportMethod: ExportMethod = .appStore
) -> AnyAction {
    AnyAction(ArchiveAction(options: .init(
        scheme: scheme,
        configuration: configuration,
        exportMethod: exportMethod
    )))
}
```

### 6. CLI Commands

**InitCommand** — scaffolds Laner directory:

```swift
struct InitCommand: AsyncParsableCommand {
    func run() async throws {
        // Creates Laner/Lanerfile.swift with template
    }
}
```

**EditCommand** — opens manifest in Xcode with autocompletion:

```swift
struct EditCommand: AsyncParsableCommand {
    func run() async throws {
        // Generates temporary Xcode project for editing
        // Opens in Xcode with LanerDSL autocomplete
    }
}
```

**LaneCommand:**

```swift
struct LaneCommand: AsyncParsableCommand {
    @Argument var laneName: String

    func run() async throws {
        let compiler = ManifestCompiler()
        let manifest = try await compiler.compile(at: findManifestPath())
        let config = try await loadConfiguration(from: manifest)

        guard let lane = config.lane(named: laneName) else {
            throw CLIError.laneNotFound(laneName)
        }

        let runner = LaneRunner()
        let result = await runner.run(lane)
        // Handle result
    }
}
```

## File Structure After Implementation

```
Sources/LanerDSL/
├── Builders/
│   ├── LaneBuilder.swift
│   └── ActionBuilder.swift
├── Actions/
│   ├── Functions.swift          # gym(), scan(), archive()
│   ├── GymAction.swift
│   ├── ScanAction.swift
│   └── ArchiveAction.swift
├── Manifest/
│   ├── Lanerfile.swift      # Root manifest type
│   └── ManifestCodable.swift    # JSON serialization
└── ... (existing files)

Sources/LanerCore/
├── Commands/
│   ├── LaneCommand.swift
│   ├── LanesCommand.swift
│   ├── InitCommand.swift
│   └── EditCommand.swift
├── Manifest/
│   ├── ManifestCompiler.swift
│   ├── ManifestLoader.swift
│   └── ManifestCache.swift
└── ... (existing files)
```

## Sequence Diagram: Lane Execution

```
User                CLI              ManifestCompiler       LaneRunner
  │                  │                      │                   │
  │ laner lane   │                      │                   │
  │     build        │                      │                   │
  │─────────────────>│                      │                   │
  │                  │                      │                   │
  │                  │ compile(manifest)    │                   │
  │                  │─────────────────────>│                   │
  │                  │                      │                   │
  │                  │                      │ swift build       │
  │                  │                      │ (if not cached)   │
  │                  │                      │                   │
  │                  │                      │ run executable    │
  │                  │                      │ → JSON output     │
  │                  │                      │                   │
  │                  │   Lanerfile      │                   │
  │                  │<─────────────────────│                   │
  │                  │                      │                   │
  │                  │ run(lane, context)   │                   │
  │                  │──────────────────────────────────────────>│
  │                  │                      │   LaneResult      │
  │                  │<──────────────────────────────────────────│
  │   Result         │                      │                   │
  │<─────────────────│                      │                   │
```

## Caching Strategy

To avoid recompilation on every run:

1. **Hash source files** — SHA256 of Lanerfile.swift + helpers
2. **Store cache** — `~/.laner/cache/<project-hash>/`
3. **Invalidate** — when source hash changes
4. **TTL** — optional time-based expiry (e.g., 24h)

```swift
struct ManifestCache {
    let cacheDirectory: URL  // ~/.laner/cache/

    func get(for manifestPath: URL) async throws -> CompiledManifest?
    func store(_ manifest: CompiledManifest, for path: URL) async throws
    func invalidate(for path: URL) async throws
}
```

## Comparison with Alternatives

| Aspect           | JSON Config | Embedded Library   | Swift Manifest (chosen) |
| ---------------- | ----------- | ------------------ | ----------------------- |
| Type safety      | Runtime     | Compile-time       | Compile-time            |
| IDE autocomplete | No          | Yes                | Yes                     |
| User setup       | Create JSON | Add SPM dependency | Run `laner init`        |
| Cold start       | Fast        | N/A                | ~2-3s (compilation)     |
| Warm start       | Fast        | N/A                | Fast (cached)           |
| Flexibility      | Limited     | Full Swift         | Full Swift              |

**Decision:** Swift manifest compilation provides best DX with acceptable cold-start overhead. Caching makes subsequent runs fast.

## Testing Strategy

```toon
tests[5]{type,coverage}:
  Unit tests,LaneBuilder/ActionBuilder result builders
  Unit tests,ManifestCompiler compilation logic
  Unit tests,ManifestCache invalidation
  Integration tests,Full manifest compile → execute flow
  Fixture tests,Sample Lanerfile.swift files
```

## Edge Cases

1. **No Swift toolchain** — clear error message with installation instructions
2. **Compilation errors** — forward Swift compiler errors to user
3. **Missing LanerDSL** — auto-resolve from laner installation path
4. **Helpers with syntax errors** — include file path in error output
5. **Concurrent compilation** — use file locks to prevent race conditions
