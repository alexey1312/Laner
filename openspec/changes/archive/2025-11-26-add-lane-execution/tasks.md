# Tasks: add-lane-execution

## Task List

```toon
tasks[16]{id,task,depends,parallel}:
  1,Create LaneBuilder result builder,-,yes
  2,Create Swiftlanefile manifest type,-,yes
  3,Add Lane initializer with @LaneBuilder,1,-
  4,Create gym() action function,-,yes
  5,Create scan() action function,-,yes
  6,Create archive() action function,-,yes
  7,Create GymAction implementation,4,-
  8,Create ScanAction implementation,5,-
  9,Create ArchiveAction implementation,6,-
  10,Create ManifestCompiler actor,-,-
  11,Create ManifestCache for compilation caching,10,-
  12,Create ManifestLoader to run compiled manifest,10 11,-
  13,Create InitCommand CLI command,-,yes
  14,Create LanesCommand CLI command,12,-
  15,Create LaneCommand CLI command,12,-
  16,Add integration tests,14 15,-
```

## Detailed Tasks

### Task 1: Create LaneBuilder result builder

**File:** `Sources/SwiftlaneDSL/Builders/LaneBuilder.swift`

- Implement `@resultBuilder` struct
- Support `buildBlock`, `buildOptional`, `buildEither`, `buildArray`, `buildExpression`
- Handle `AnyAction` array construction
- Add unit tests

**Validation:** `swift test --filter LaneBuilderTests`

---

### Task 2: Create Swiftlanefile manifest type

**File:** `Sources/SwiftlaneDSL/Manifest/Swiftlanefile.swift`

- Create `Swiftlanefile` struct as root configuration type
- Properties: `lanes: [Lane]`
- Conform to `Codable` for JSON serialization
- Add `lane(named:)` lookup method

```swift
public struct Swiftlanefile: Codable, Sendable {
    public let lanes: [Lane]

    public init(lanes: [Lane]) {
        self.lanes = lanes
    }

    public func lane(named name: String) -> Lane? {
        lanes.first { $0.name == name }
    }
}
```

**Validation:** `swift test --filter SwiftlanefileTests`

---

### Task 3: Add Lane initializer with @LaneBuilder

**File:** `Sources/SwiftlaneDSL/Lane.swift`

- Add new `init` using `@LaneBuilder`
- Keep existing initializers for backward compatibility
- Update Lane to be `Codable`

```swift
public init(
    _ name: String,
    description: String = "",
    @LaneBuilder actions: () -> [AnyAction]
)
```

**Validation:** Existing tests pass, new DSL syntax compiles

---

### Task 4: Create gym() action function

**File:** `Sources/SwiftlaneDSL/Actions/Functions.swift`

- Create `gym()` function returning `AnyAction`
- Parameters: scheme, workspace, project, configuration, destination
- Wrap `GymAction` creation

**Validation:** `swift build` succeeds

---

### Task 5: Create scan() action function

**File:** `Sources/SwiftlaneDSL/Actions/Functions.swift`

- Create `scan()` function returning `AnyAction`
- Parameters: scheme, workspace, devices, codeCoverage
- Wrap `ScanAction` creation

**Validation:** `swift build` succeeds

---

### Task 6: Create archive() action function

**File:** `Sources/SwiftlaneDSL/Actions/Functions.swift`

- Create `archive()` function returning `AnyAction`
- Parameters: scheme, configuration, exportMethod
- Wrap `ArchiveAction` creation

**Validation:** `swift build` succeeds

---

### Task 7: Create GymAction implementation

**File:** `Sources/SwiftlaneDSL/Actions/GymAction.swift`

- Implement `Action` protocol
- Wrap `XcodebuildExecutor.build`
- Create `GymOptions` struct (Codable)
- Return `BuildResult`

**Validation:** `swift test --filter GymActionTests`

---

### Task 8: Create ScanAction implementation

**File:** `Sources/SwiftlaneDSL/Actions/ScanAction.swift`

- Implement `Action` protocol
- Wrap `XcodebuildExecutor.test`
- Create `ScanOptions` struct (Codable)
- Return `TestResult`

**Validation:** `swift test --filter ScanActionTests`

---

### Task 9: Create ArchiveAction implementation

**File:** `Sources/SwiftlaneDSL/Actions/ArchiveAction.swift`

- Implement `Action` protocol
- Wrap `XcodebuildExecutor.archive`
- Create `ArchiveOptions` struct (Codable)
- Add archive artifact to context

**Validation:** `swift test --filter ArchiveActionTests`

---

### Task 10: Create ManifestCompiler actor

**File:** `Sources/SwiftlaneCore/Manifest/ManifestCompiler.swift`

- Actor for thread-safe compilation
- Generate temporary Package.swift with SwiftlaneDSL dependency
- Run `swift build` to compile manifest
- Execute compiled binary to get JSON output
- Parse JSON to `Swiftlanefile`

```swift
actor ManifestCompiler {
    func compile(at path: URL) async throws -> Swiftlanefile
}
```

**Validation:** `swift test --filter ManifestCompilerTests`

---

### Task 11: Create ManifestCache

**File:** `Sources/SwiftlaneCore/Manifest/ManifestCache.swift`

- Cache compiled manifests in `~/.swiftlane/cache/`
- Hash source files (SHA256) for cache key
- Invalidate on source change
- Store compiled executable path

```swift
struct ManifestCache {
    func get(for manifestPath: URL) async throws -> CachedManifest?
    func store(_ manifest: CachedManifest, for path: URL) async throws
    func invalidate(for path: URL) async throws
}
```

**Validation:** `swift test --filter ManifestCacheTests`

---

### Task 12: Create ManifestLoader

**File:** `Sources/SwiftlaneCore/Manifest/ManifestLoader.swift`

- Find `Swiftlane/Swiftlanefile.swift` in project
- Check cache first, compile if needed
- Return parsed `Swiftlanefile`

```swift
struct ManifestLoader {
    func load(from directory: URL) async throws -> Swiftlanefile
    func findManifestPath(in directory: URL) throws -> URL
}
```

**Validation:** `swift test --filter ManifestLoaderTests`

---

### Task 13: Create InitCommand

**File:** `Sources/SwiftlaneCore/Commands/InitCommand.swift`

- Create `Swiftlane/` directory
- Generate `Swiftlanefile.swift` template
- Print success message with next steps

```bash
$ swiftlane init
Created Swiftlane/Swiftlanefile.swift
Run 'swiftlane lanes' to see available lanes
```

**Validation:** Manual test

---

### Task 14: Create LanesCommand

**File:** `Sources/SwiftlaneCore/Commands/LanesCommand.swift`

- Load manifest via ManifestLoader
- Print lane names and descriptions
- Handle no manifest found error

```bash
$ swiftlane lanes
Available lanes:
  build   - Build the app for development
  test    - Run all unit tests
  release - Build and archive for release
```

**Validation:** `swift test --filter LanesCommandTests`

---

### Task 15: Create LaneCommand

**File:** `Sources/SwiftlaneCore/Commands/LaneCommand.swift`

- Argument: lane name
- Load manifest via ManifestLoader
- Find lane by name
- Execute with LaneRunner
- Print result summary

```bash
$ swiftlane lane build
Compiling Swiftlanefile... (first run)
Running lane 'build'...
  ▸ gym(scheme: App)
Lane 'build' completed in 45.2s
```

**Validation:** `swift test --filter LaneCommandTests`

---

### Task 16: Add integration tests

**Files:**
- `Tests/SwiftlaneCoreTests/ManifestIntegrationTests.swift`
- `Tests/Fixtures/Swiftlane/Swiftlanefile.swift`

- Test full compile → load → execute flow
- Test caching behavior
- Test error handling (missing manifest, compilation errors)

**Validation:** `swift test --filter IntegrationTests`

## Parallelization

**Phase 1 (parallel):** Tasks 1, 2, 4, 5, 6, 13
**Phase 2 (sequential):** Tasks 3, 7, 8, 9 (depend on phase 1)
**Phase 3 (sequential):** Tasks 10, 11, 12 (manifest system)
**Phase 4 (sequential):** Tasks 14, 15 (CLI commands)
**Phase 5:** Task 16 (integration tests)

## Definition of Done

- [x] All tasks completed
- [x] `swift build` succeeds
- [x] `swift test` passes (148 tests)
- [x] `swiftlane init` creates template
- [x] `swiftlane lanes` lists lanes from manifest
- [x] `swiftlane lane build` compiles and executes lane
- [x] Second run uses cache (fast)
- [x] Examples/ updated with new syntax
