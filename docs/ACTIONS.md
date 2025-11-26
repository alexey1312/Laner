# SwiftlaneDSL Actions

This directory contains action implementations for the Swiftlane DSL.

## Available Actions

### Build Actions

- **gym**: Build iOS/macOS apps using xcodebuild
- **scan**: Run tests using xcodebuild
- **archive**: Archive and export IPAs

### Code Signing Actions

- **match**: Sync code signing certificates and provisioning profiles
- **registerDevices**: Register devices with Apple Developer Portal

## Match Action

The `match()` action syncs code signing certificates and provisioning profiles from a Git repository, similar to Fastlane Match. It supports:

- Multiple certificate types (development, distribution, adhoc, appstore)
- App-specific profile syncing
- Readonly mode to prevent certificate creation
- Force regeneration of profiles when new devices are added
- Custom Git URLs and branches

### Usage

```swift
lane("sign") {
    match(
        type: .development,
        appIdentifier: "com.example.app"
    )
}
```

### Configuration

Match can be configured via:

1. **Function parameters** (highest priority)
2. **Environment variables**:
   - `MATCH_PASSWORD`: Encryption password for certificates
   - `MATCH_GIT_URL`: Git repository URL
   - `MATCH_TEAM_ID`: Apple Developer team ID
   - `MATCH_GIT_BRANCH`: Git branch (defaults to "master")
   - `MATCH_READONLY`: Run in readonly mode ("true" or "false")
   - `MATCH_FORCE_FOR_NEW_DEVICES`: Force profile regeneration ("true" or "false")
   - `APP_STORE_CONNECT_API_KEY_ID`: API key ID
   - `APP_STORE_CONNECT_API_ISSUER_ID`: API issuer ID
   - `APP_STORE_CONNECT_API_KEY_PATH`: Path to API private key (.p8)

### Examples

**Basic usage:**
```swift
match(type: .appstore, appIdentifier: "com.example.app")
```

**Readonly mode:**
```swift
match(type: .appstore, appIdentifier: "com.example.app", readonly: true)
```

**Force regeneration for new devices:**
```swift
match(type: .adhoc, forceForNewDevices: true)
```

**Custom Git repository:**
```swift
match(
    type: .distribution,
    gitUrl: "https://github.com/example/certs.git",
    branch: "develop"
)
```

**Multiple apps:**
```swift
lane("sign_all") {
    match(type: .appstore, appIdentifier: "com.example.app")
    match(type: .appstore, appIdentifier: "com.example.app.watchkitapp")
    match(type: .appstore, appIdentifier: "com.example.app.extension")
}
```

## Register Devices Action

The `registerDevices()` action registers devices with the Apple Developer Portal. It supports:

- Registration from a file (tab-separated: Name\tUDID)
- Registration from a dictionary
- Multiple platforms (iOS, macOS, tvOS, watchOS, visionOS)
- Duplicate detection (skips already registered devices)

### Usage

**From file:**
```swift
registerDevices(file: "devices.txt")
```

**From dictionary:**
```swift
registerDevices(devices: [
    "John's iPhone": "00008030-001234567890401E",
    "Jane's iPad": "00008101-000123456789012E"
])
```

### Configuration

Register devices requires App Store Connect API credentials:

- `APP_STORE_CONNECT_API_KEY_ID`: API key ID (or pass via `apiKeyId:` parameter)
- `APP_STORE_CONNECT_API_ISSUER_ID`: API issuer ID (or pass via `apiIssuerId:` parameter)
- `APP_STORE_CONNECT_API_KEY_PATH`: Path to API private key (or pass via `apiKeyPath:` parameter)
- `MATCH_TEAM_ID`: Apple Developer team ID (or pass via `teamId:` parameter)

### File Format

The devices file should contain one device per line in tab-separated format:

```
iPhone 15 Pro	00008030-001234567890401E
iPad Pro	00008101-000123456789012E
Test Device	00008020-001A1B2C3D4E501F
```

Lines starting with `#` are treated as comments and ignored.

### Examples

**Register devices and sync ad-hoc profiles:**
```swift
lane("adhoc") {
    registerDevices(file: "devices.txt")
    match(type: .adhoc, forceForNewDevices: true)
    gym(scheme: "MyApp", exportMethod: .adHoc)
}
```

**Register specific platform:**
```swift
registerDevices(file: "macs.txt", platform: .macOS)
```

**Register with explicit credentials:**
```swift
registerDevices(
    devices: ["Test iPhone": "00008030-001234567890401E"],
    teamId: "TEAM123",
    apiKeyId: "KEY123",
    apiIssuerId: "ISSUER123",
    apiKeyPath: "/path/to/key.p8"
)
```

## Creating New Actions

To create a new action:

1. Define an `Options` struct conforming to `Sendable`
2. Create an action struct conforming to `Action` protocol
3. Implement `execute(context:)` method
4. Add a DSL function that returns `AnyAction`
5. Write unit tests

### Example Template

```swift
import Foundation

// Options struct
public struct MyActionOptions: Sendable {
    public let parameter: String

    public init(parameter: String) {
        self.parameter = parameter
    }
}

// Action implementation
public struct MyAction: Action {
    public typealias Options = MyActionOptions
    public typealias Result = Void

    public static let name = "my_action"
    public static let description = "Description of what this action does"

    public let options: MyActionOptions

    public init(options: MyActionOptions) {
        self.options = options
    }

    @MainActor
    public func execute(context: ExecutionContext) async throws {
        context.logger.info("[\(Self.name)] Executing with parameter: \(options.parameter)")
        // Implementation here
    }
}

// DSL function
public func myAction(parameter: String) -> AnyAction {
    AnyAction(MyAction(options: MyActionOptions(parameter: parameter)))
}
```

## Testing Actions

All actions should have comprehensive unit tests covering:

- Options initialization
- Action metadata (name, description)
- Type erasure (AnyAction wrapping)
- DSL function creation
- Error handling
- Sendable conformance

See `MatchActionTests.swift` for examples.
