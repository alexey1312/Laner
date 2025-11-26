# Swiftlane — Swift-Based Fastlane Replacement

## Overview

**Swiftlane** — open-source Swift CLI инструмент для iOS CI/CD, полностью заменяющий Fastlane.

**Цели:**
- Избавиться от Ruby зависимости
- Ускорить CI pipeline
- Type-safe конфигурация через Swift DSL
- Образовательный проект для понимания CI/CD изнутри
- **Кроссплатформенность: macOS + Linux**

## Architecture

### Project Structure

```
swiftlane/
├── Package.swift
├── Sources/
│   ├── Swiftlane/                    # Main executable
│   │   └── main.swift
│   ├── SwiftlaneCore/                # Core business logic
│   │   ├── Commands/                 # CLI commands
│   │   │   ├── BuildCommand.swift
│   │   │   ├── TestCommand.swift
│   │   │   ├── ArchiveCommand.swift
│   │   │   ├── CertificatesCommand.swift
│   │   │   ├── UploadCommand.swift
│   │   │   └── ...
│   │   ├── Executors/                # Shell & API executors
│   │   │   ├── XcodebuildExecutor.swift
│   │   │   ├── SimctlExecutor.swift
│   │   │   └── ShellExecutor.swift
│   │   ├── Services/                 # External integrations
│   │   │   ├── AppStoreConnect/
│   │   │   ├── Firebase/
│   │   │   ├── Match/                # Code signing
│   │   │   └── Notifications/
│   │   ├── Configuration/            # DSL & config parsing
│   │   │   ├── Swiftlanefile.swift
│   │   │   └── Environment.swift
│   │   └── Models/
│   ├── SwiftlaneDSL/                 # Public DSL for users
│   │   ├── Lane.swift
│   │   ├── Actions.swift
│   │   └── Plugins.swift
│   └── SwiftlaneKit/                 # Shared utilities
│       ├── Logging.swift
│       ├── FileManager+Extensions.swift
│       └── Process+Extensions.swift
├── Tests/
├── Plugins/                          # Optional plugins
└── Examples/
    └── Swiftlanefile.swift           # Example config
```

### Swift DSL Design

```swift
// Swiftlane/Swiftlanefile.swift — project configuration
import SwiftlaneDSL

let swiftlane = Swiftlanefile(
    lanes: [
        Lane("build") {
            gym(scheme: "App", configuration: .debug)
        },

        Lane("build_release") {
            certificates(type: .appstore)
            gym(scheme: "App", configuration: .release, exportMethod: .appStore)
        },

        Lane("test") {
            scan(scheme: "AppTests", codeCoverage: true)
        },

        Lane("upload_firebase") {
            firebaseDistribution(groups: ["testers"], releaseNotes: defaultChangelog())
        },

        Lane("upload_testflight") {
            pilot(skipWaitingForProcessing: true)
        },

        Lane("certificates") {
            match(type: .development)
            match(type: .adhoc)
        }
    ]
)
```

## Implementation Phases

### Phase 1: Foundation (2-3 weeks)

**Goal:** Базовый CLI с xcodebuild wrapper

**Deliverables:**
1. Swift Package structure
2. ArgumentParser integration
3. `ShellExecutor` — async process runner
4. `XcodebuildExecutor` — build/test/archive
5. Basic commands: `swiftlane build`, `swiftlane test`

**Key Files:**
```swift
// ShellExecutor.swift
actor ShellExecutor {
    func run(_ command: String, arguments: [String]) async throws -> ProcessResult
    func stream(_ command: String, arguments: [String]) -> AsyncStream<String>
}

// XcodebuildExecutor.swift
struct XcodebuildExecutor {
    func build(options: BuildOptions) async throws -> BuildResult
    func test(options: TestOptions) async throws -> TestResult
    func archive(options: ArchiveOptions) async throws -> ArchiveResult
}
```

**Dependencies:**
- `apple/swift-argument-parser` — CLI parsing
- `apple/swift-log` — logging

---

### Phase 2: DSL & Configuration (2 weeks)

**Goal:** Swift DSL для конфигурации lanes

**Deliverables:**
1. `SwiftlaneDSL` module с result builders
2. `Lane` protocol и `@LaneBuilder`
3. Actions API (gym, scan, match, etc.)
4. Environment variables handling
5. Swiftlanefile compilation & execution

**Key Pattern — Result Builder:**
```swift
@resultBuilder
struct LaneBuilder {
    static func buildBlock(_ components: Action...) -> [Action] {
        components
    }

    static func buildOptional(_ component: [Action]?) -> [Action] {
        component ?? []
    }

    static func buildEither(first: [Action]) -> [Action] { first }
    static func buildEither(second: [Action]) -> [Action] { second }
}

struct Lane {
    let name: String
    let actions: [Action]

    init(_ name: String, @LaneBuilder actions: () -> [Action]) {
        self.name = name
        self.actions = actions()
    }
}
```

---

### Phase 3: Code Signing — Match Alternative (3 weeks)

**Goal:** Полная замена fastlane match

**Deliverables:**
1. Git-based certificate storage
2. AES-256 encryption/decryption (CryptoKit)
3. Keychain integration
4. Provisioning profile management
5. Device registration via App Store Connect API

**Architecture:**
```swift
struct MatchService {
    let git: GitRepository
    let crypto: CryptoService
    let keychain: KeychainService
    let appStoreConnect: AppStoreConnectAPI

    func sync(type: CertificateType) async throws
    func register(devices: [Device]) async throws
    func nuke(type: CertificateType) async throws
}

struct CryptoService {
    // AES-256-GCM encryption (same as Match)
    func encrypt(data: Data, password: String) throws -> Data
    func decrypt(data: Data, password: String) throws -> Data
}
```

**Dependencies:**
- `CryptoKit` (built-in)
- `Security.framework` for Keychain

---

### Phase 4: App Store Connect Integration (2 weeks)

**Goal:** Upload to TestFlight, manage builds

**Deliverables:**
1. JWT authentication
2. Build upload (altool/iTMSTransporter wrapper)
3. Build management API
4. TestFlight distribution

**Key Integration:**
```swift
struct AppStoreConnectAPI {
    let credentials: APICredentials

    func uploadBuild(ipa: URL) async throws -> Build
    func listBuilds(app: String) async throws -> [Build]
    func submitForReview(build: Build) async throws
    func registerDevices(_ devices: [Device]) async throws
}
```

**Option:** Use `AvdLee/appstoreconnect-swift-sdk` or implement from scratch

---

### Phase 5: Firebase App Distribution (1 week)

**Goal:** Upload to Firebase

**Deliverables:**
1. Firebase CLI wrapper OR REST API integration
2. Release notes generation
3. Tester groups management

```swift
struct FirebaseDistributionService {
    func upload(ipa: URL, groups: [String], notes: String) async throws
}
```

---

### Phase 6: Notifications & Integrations (1 week)

**Goal:** Jira, Slack notifications

**Deliverables:**
1. Jira REST API integration
2. Slack webhook support
3. Generic webhook support
4. Changelog generation from git

```swift
protocol NotificationService {
    func send(message: String) async throws
}

struct JiraNotificationService: NotificationService { }
struct SlackNotificationService: NotificationService { }
```

---

### Phase 7: Metrics & Telemetry (1 week)

**Goal:** Build time tracking, size metrics

**Deliverables:**
1. Build timing instrumentation
2. IPA size tracking
3. Telemetry API integration
4. Grafana-compatible output

---

### Phase 8: Polish & Documentation (2 weeks)

**Goal:** Production-ready release

**Deliverables:**
1. Comprehensive documentation
2. Example Swiftlanefiles
3. Migration guide from Fastlane
4. CI templates (GitHub Actions)
5. Homebrew formula

## Dependencies

| Package | Version | Purpose | Linux Support |
|---------|---------|---------|---------------|
| swift-argument-parser | 1.3+ | CLI argument parsing | ✅ |
| swift-log | 1.5+ | Structured logging | ✅ |
| swift-crypto | 3.0+ | Encryption (replaces CryptoKit on Linux) | ✅ |
| async-http-client | 1.19+ | HTTP requests | ✅ |
| Yams | 5.0+ | YAML parsing | ✅ |

## Linux Support Strategy

### Platform-Specific Code

```swift
// Use swift-crypto instead of CryptoKit for cross-platform
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto  // swift-crypto
#endif

// Platform detection
#if os(Linux)
// Linux-specific implementations
#elseif os(macOS)
// macOS-specific (Keychain, Security.framework)
#endif
```

### Feature Availability by Platform

| Feature | macOS | Linux |
|---------|-------|-------|
| Build/Test (xcodebuild) | ✅ | ❌ (macOS only) |
| Swift Package build | ✅ | ✅ |
| App Store Connect API | ✅ | ✅ |
| Firebase upload | ✅ | ✅ |
| Match (certificates) | ✅ | ❌ (Keychain required) |
| Notifications (Jira/Slack) | ✅ | ✅ |
| Metrics/Telemetry | ✅ | ✅ |

### Linux Use Cases

1. **API-only operations** — upload to Firebase/TestFlight from Linux CI
2. **Notifications** — send Slack/Jira notifications
3. **Metrics collection** — aggregate and send telemetry
4. **Swift Package builds** — build/test SPM packages

### Conditional Compilation

```swift
// Package.swift
let package = Package(
    name: "swiftlane",
    platforms: [.macOS(.v13)],  // macOS minimum
    // Linux uses latest Swift toolchain
    ...
)

// Runtime check for available features
public struct PlatformCapabilities {
    public static var canBuildXcode: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    public static var canAccessKeychain: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
}

## CLI Interface

```bash
# Build
swiftlane build                    # Default build
swiftlane build --scheme MyScheme  # Custom scheme
swiftlane build --simulator        # Simulator build

# Test
swiftlane test
swiftlane test --retry-failed      # Retry failed tests

# Certificates
swiftlane certificates --type adhoc
swiftlane certificates --type appstore
swiftlane match sync               # Sync certificates
swiftlane match register           # Register new devices

# Upload
swiftlane upload firebase --groups testers
swiftlane upload testflight

# Custom lanes
swiftlane prepare                  # Run 'prepare' lane
swiftlane my_custom_lane           # Any custom lane

# Utilities
swiftlane init                     # Generate Swiftlanefile.swift
swiftlane doctor                   # Check environment
swiftlane lanes                    # List available lanes
```

## Migration Strategy from Fastlane

### Step 1: Parallel Operation
- Keep existing Fastfile
- Add `Swiftlane/Swiftlanefile.swift` alongside
- Gradually migrate lanes one by one

### Step 2: CI Integration
```yaml
# GitHub Actions
- name: Build with Swiftlane
  run: |
    brew install swiftlane
    swiftlane lane build
```

### Step 3: Full Migration
- Remove Fastfile, Gemfile, fastlane/
- Update CI workflows
- Update documentation

## Success Metrics

1. **Performance:** CI build time reduced by 20%+
2. **Developer Experience:** Zero Ruby knowledge required
3. **Reliability:** Type-safe configuration catches errors at compile time
4. **Adoption:** Other teams can use via SPM/Homebrew

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Match encryption compatibility | Use same AES-256-GCM algorithm |
| App Store Connect API changes | Abstract behind protocol, easy to update |
| Large initial investment | Phased approach, MVP first |
| Missing edge cases | Extensive testing against real projects |

## Plugin Architecture

### Plugin Protocol

```swift
// SwiftlanePluginKit/Plugin.swift
public protocol SwiftlanePlugin {
    static var name: String { get }
    static var version: String { get }

    /// Actions provided by this plugin
    static var actions: [Action.Type] { get }

    /// Called when plugin is loaded
    static func register(with registry: ActionRegistry)
}

// Example plugin implementation
public struct FirebasePlugin: SwiftlanePlugin {
    public static let name = "Firebase"
    public static let version = "1.0.0"

    public static var actions: [Action.Type] {
        [FirebaseUploadAction.self, FirebaseCrashlyticsAction.self]
    }

    public static func register(with registry: ActionRegistry) {
        registry.register(FirebaseUploadAction.self)
        registry.register(FirebaseCrashlyticsAction.self)
    }
}
```

### Plugin Distribution

```swift
// Package.swift for a plugin
let package = Package(
    name: "SwiftlaneFirebase",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwiftlaneFirebase", targets: ["SwiftlaneFirebase"])
    ],
    dependencies: [
        .package(url: "https://github.com/user/swiftlane.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftlaneFirebase",
            dependencies: [
                .product(name: "SwiftlanePluginKit", package: "swiftlane")
            ]
        )
    ]
)
```

### Plugin Loading

```swift
// In Swiftlane/Swiftlanefile.swift
import SwiftlaneDSL
import SwiftlaneFirebase  // Plugin as SPM dependency

let swiftlane = Swiftlanefile(
    plugins: [FirebasePlugin.self],
    lanes: [
        Lane("deploy") {
            // Action from plugin
            firebaseUpload(groups: ["testers"])
        }
    ]
)
```

---

## Repository Setup

**Location:** `/Users/aleksei/Developer/swiftlane`

### Initial Structure

```bash
/Users/aleksei/Developer/swiftlane/
├── Package.swift
├── README.md
├── LICENSE                          # MIT
├── Sources/
│   ├── swiftlane/                   # CLI executable
│   │   └── main.swift
│   ├── SwiftlaneCore/               # Core logic (internal)
│   ├── SwiftlaneDSL/                # Public DSL API
│   ├── SwiftlanePluginKit/          # Plugin development kit
│   └── SwiftlaneKit/                # Shared utilities
├── Tests/
│   ├── SwiftlaneCoreTests/
│   ├── SwiftlaneDSLTests/
│   └── IntegrationTests/
├── Plugins/                         # Built-in plugins
│   ├── SwiftlaneFirebase/
│   ├── SwiftlaneAppStore/
│   └── SwiftlaneMatch/
└── Examples/
    ├── BasicSwiftlanefile.swift
    └── AdvancedSwiftlanefile.swift
```

### Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swiftlane",
    platforms: [.macOS(.v13)],
    products: [
        // CLI executable
        .executable(name: "swiftlane", targets: ["swiftlane"]),

        // Libraries for plugin development
        .library(name: "SwiftlaneDSL", targets: ["SwiftlaneDSL"]),
        .library(name: "SwiftlanePluginKit", targets: ["SwiftlanePluginKit"]),
        .library(name: "SwiftlaneKit", targets: ["SwiftlaneKit"]),

        // Built-in plugins (optional)
        .library(name: "SwiftlaneFirebase", targets: ["SwiftlaneFirebase"]),
        .library(name: "SwiftlaneAppStore", targets: ["SwiftlaneAppStore"]),
        .library(name: "SwiftlaneMatch", targets: ["SwiftlaneMatch"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        // Main executable
        .executableTarget(
            name: "swiftlane",
            dependencies: [
                "SwiftlaneCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // Core (internal implementation)
        .target(
            name: "SwiftlaneCore",
            dependencies: [
                "SwiftlaneDSL",
                "SwiftlaneKit",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),

        // Public DSL for users
        .target(
            name: "SwiftlaneDSL",
            dependencies: ["SwiftlaneKit"]
        ),

        // Plugin development kit
        .target(
            name: "SwiftlanePluginKit",
            dependencies: ["SwiftlaneDSL", "SwiftlaneKit"]
        ),

        // Shared utilities
        .target(name: "SwiftlaneKit"),

        // Built-in plugins
        .target(
            name: "SwiftlaneFirebase",
            dependencies: ["SwiftlanePluginKit"],
            path: "Plugins/SwiftlaneFirebase"
        ),
        .target(
            name: "SwiftlaneAppStore",
            dependencies: ["SwiftlanePluginKit"],
            path: "Plugins/SwiftlaneAppStore"
        ),
        .target(
            name: "SwiftlaneMatch",
            dependencies: ["SwiftlanePluginKit", "SwiftlaneKit"],
            path: "Plugins/SwiftlaneMatch"
        ),

        // Tests
        .testTarget(name: "SwiftlaneCoreTests", dependencies: ["SwiftlaneCore"]),
        .testTarget(name: "SwiftlaneDSLTests", dependencies: ["SwiftlaneDSL"]),
    ]
)
```

---

## Full Architecture Design

### Module Dependency Graph

```
                    ┌──────────────┐
                    │   swiftlane  │  (CLI executable)
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │SwiftlaneCore │  (Internal logic)
                    └──────┬───────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
   ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
   │SwiftlaneDSL │  │PluginKit   │  │SwiftlaneKit │
   └─────────────┘  └─────────────┘  └─────────────┘
          │                │
          └────────┬───────┘
                   │
        ┌──────────▼──────────┐
        │   User Plugins      │
        │ (SwiftlaneFirebase, │
        │  SwiftlaneMatch...) │
        └─────────────────────┘
```

### Core Protocols

```swift
// MARK: - Action Protocol

public protocol Action {
    associatedtype Options: Codable
    associatedtype Result

    static var name: String { get }
    static var description: String { get }

    init(options: Options)
    func execute(context: ExecutionContext) async throws -> Result
}

// MARK: - Execution Context

public struct ExecutionContext {
    public let environment: Environment
    public let logger: Logger
    public let fileManager: FileManager
    public let shell: ShellExecutor

    // Shared state between actions
    public var artifacts: ArtifactStore
}

// MARK: - Lane Definition

public struct Lane {
    public let name: String
    public let description: String?
    public let actions: [AnyAction]
    public let options: LaneOptions?

    public init(
        _ name: String,
        description: String? = nil,
        @LaneBuilder actions: () -> [AnyAction]
    )
}

// MARK: - Configuration Protocol

public protocol SwiftlaneConfiguration {
    static var plugins: [SwiftlanePlugin.Type] { get }
    static var lanes: [Lane] { get }

    static func beforeAll(lane: String) async throws
    static func afterAll(lane: String, result: LaneResult) async throws
    static func onError(lane: String, error: Error) async throws
}

extension SwiftlaneConfiguration {
    // Default implementations
    public static var plugins: [SwiftlanePlugin.Type] { [] }
    public static func beforeAll(lane: String) async throws { }
    public static func afterAll(lane: String, result: LaneResult) async throws { }
    public static func onError(lane: String, error: Error) async throws { }
}
```

### Built-in Actions

```swift
// Build Actions
gym(workspace:scheme:configuration:exportMethod:)
scan(workspace:scheme:devices:codeCoverage:)
archive(workspace:scheme:destination:)

// Code Signing (Match plugin)
match(type:readonly:)
certificates(type:)
registerDevices(file:)

// Upload (AppStore plugin)
pilot(ipa:changelog:)
deliver(ipa:metadata:)

// Upload (Firebase plugin)
firebaseDistribution(ipa:groups:releaseNotes:)
firebaseCrashlytics(dsym:)

// Utilities
defaultChangelog(commits:)
ensureXcodeVersion(version:)
xcodeSelect(version:)
shell(command:)

// Notifications
slack(message:channel:)
jira(ticket:comment:)
```

---

## Implementation Order (Full Design First)

### Week 1-2: Architecture & Interfaces

1. **Define all protocols and interfaces**
   - `Action`, `Lane`, `SwiftlaneConfiguration`
   - `SwiftlanePlugin`, `ActionRegistry`
   - `ExecutionContext`, `Environment`

2. **Design DSL with result builders**
   - `@LaneBuilder`, `@ActionBuilder`
   - Type-safe action APIs

3. **Plan error handling strategy**
   - Custom error types
   - Recovery strategies

### Week 3-4: Core Infrastructure

1. **ShellExecutor** — async process execution
2. **Logger** — structured logging with swift-log
3. **Environment** — env vars, CI detection
4. **FileManager extensions** — IPA, dSYM handling

### Week 5-6: XcodeBuild Integration

1. **XcodebuildExecutor**
   - build, test, archive
   - xcresult parsing
2. **SimctlExecutor** — simulator management
3. **gym/scan/archive actions**

### Week 7-8: Match Plugin (Code Signing)

1. **GitRepository** — clone, commit, push
2. **CryptoService** — AES-256-GCM encryption
3. **KeychainService** — certificate installation
4. **match action**

### Week 9-10: AppStore Plugin

1. **JWT authentication**
2. **Build upload** (altool wrapper)
3. **pilot/deliver actions**

### Week 11: Firebase Plugin

1. **Firebase REST API**
2. **firebaseDistribution action**
3. **firebaseCrashlytics action**

### Week 12: Polish

1. **Documentation**
2. **Example Swiftlanefiles**
3. **Migration guide**
4. **Homebrew formula**

---

## Comparison with Danger Swift

### Danger Swift Architecture ([source](https://danger.systems/swift/tutorials/architecture))

**"Swift sandwich":** Danger JS → Danger Swift → Danger JS
- Danger JS handles CI/platform detection (GitHub, GitLab, BitBucket)
- Swift only processes rules
- JSON as transport between layers

**Plugin approach** ([source](https://danger.systems/swift/usage/extending_danger.html)):
- No protocol — just public functions
- Plugin = SPM package that imports `Danger` and exports functions
- Minimal abstraction:
```swift
public func checkForCopyrightHeaders() {
    let danger = Danger()
    // logic
}
```

### Why Swiftlane Differs

| Aspect | Danger Swift | Swiftlane |
|--------|--------------|-----------|
| **Dependency** | Requires Danger JS (Node.js) | Fully autonomous Swift |
| **Plugin system** | Simple functions | Protocol + Registry |
| **Type safety** | Runtime | Compile-time |
| **Lifecycle hooks** | Limited | Full (beforeAll, afterAll, onError) |
| **Plugin discovery** | Manual import | Automatic registration |
| **Testability** | Harder to mock | Protocol-based DI |

### Decision: Protocol + Registry

**Rationale:**
1. **Compile-time guarantees** — plugins must conform to `SwiftlanePlugin`
2. **Discoverability** — `swiftlane plugins list` shows all registered actions
3. **Testability** — protocol-based design enables mocking
4. **Lifecycle control** — plugins can hook into execution phases
5. **Future extensibility** — can add versioning, compatibility checks

**Trade-off accepted:** More initial complexity, but better long-term maintainability.

---

## Next Steps

1. **Create repository** at `/Users/aleksei/Developer/Swiftlane`
2. **Initialize Package.swift** with all targets
3. **Define core protocols** (Action, Lane, Plugin)
4. **Implement DSL** with result builders
5. **Build ShellExecutor** as foundation
