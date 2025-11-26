import LanerDSL
import LanerMatch

// MARK: - Basic Match Configuration Examples

/// Example 1: Basic development certificate sync
///
/// This lane syncs development certificates and provisioning profiles
/// for a single app identifier. It uses environment variables for configuration.
let developmentLane = Lane(name: "dev_certificates") {
    // Sync development certificates
    // Reads configuration from environment variables:
    // - MATCH_PASSWORD
    // - MATCH_GIT_URL
    // - MATCH_TEAM_ID
    match(
        type: .development,
        appIdentifier: "com.example.app"
    )

    // Build with matched certificates
    gym(
        scheme: "MyApp",
        configuration: .debug,
        exportMethod: .development
    )
}

/// Example 2: App Store distribution with readonly mode
///
/// This lane syncs App Store certificates in readonly mode,
/// ensuring no new certificates are created during CI builds.
let appStoreLane = Lane(name: "appstore") {
    // Readonly mode prevents creating new certificates
    match(
        type: .appstore,
        appIdentifier: "com.example.app",
        readonly: true
    )

    gym(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .appStore
    )
}

/// Example 3: Ad-Hoc distribution with force for new devices
///
/// This lane registers new devices and forces profile regeneration
/// to include the newly registered devices.
let adHocLane = Lane(name: "adhoc_with_devices") {
    // Register devices from file
    registerDevices(file: "devices.txt")

    // Force profile regeneration when new devices are added
    match(
        type: .adhoc,
        appIdentifier: "com.example.app",
        forceForNewDevices: true
    )

    gym(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .adHoc
    )
}

// MARK: - Advanced Configuration Examples

/// Example 4: Custom Git repository and branch
///
/// This example shows how to override default Git configuration
/// to use a specific repository and branch for certificates.
let customGitLane = Lane(name: "custom_git") {
    match(
        type: .development,
        appIdentifier: "com.example.app",
        teamId: "ABC123DEF4",
        gitUrl: "https://github.com/mycompany/ios-certificates.git",
        branch: "develop"
    )
}

/// Example 5: Multiple app identifiers
///
/// Sync certificates for multiple apps (main app, extensions, widgets).
let multiAppLane = Lane(name: "multi_app_sync") {
    // Main app
    match(
        type: .appstore,
        appIdentifier: "com.example.app"
    )

    // Share extension
    match(
        type: .appstore,
        appIdentifier: "com.example.app.share-extension"
    )

    // Widget extension
    match(
        type: .appstore,
        appIdentifier: "com.example.app.widget"
    )

    // Watch app
    match(
        type: .appstore,
        appIdentifier: "com.example.app.watchkitapp"
    )
}

/// Example 6: Different certificate types in one workflow
///
/// Use development certificates for debug builds and
/// distribution certificates for release builds.
let buildAllLane = Lane(name: "build_all") {
    // Development build
    match(type: .development, appIdentifier: "com.example.app")
    gym(scheme: "MyApp", configuration: .debug, exportMethod: .development)

    // App Store build
    match(type: .appstore, appIdentifier: "com.example.app")
    gym(scheme: "MyApp", configuration: .release, exportMethod: .appStore)

    // Ad-Hoc build for testing
    match(type: .adhoc, appIdentifier: "com.example.app")
    gym(scheme: "MyApp", configuration: .release, exportMethod: .adHoc)
}

// MARK: - Device Registration Examples

/// Example 7: Register devices from dictionary
///
/// Register specific devices by providing a dictionary of device names and UDIDs.
let registerDevicesLane = Lane(name: "register_devices") {
    registerDevices(devices: [
        "John's iPhone 15 Pro": "00008030-001234567890401E",
        "Jane's iPad Pro": "00008101-000123456789012E",
        "QA iPhone 14": "00008020-001A1B2C3D4E501F",
        "Test Device": "00008110-000A0B0C0D0E0F1G"
    ])
}

/// Example 8: Register devices from file
///
/// The devices.txt file should be in tab-delimited format:
/// ```
/// Device Name 1\t00008030-001234567890401E
/// Device Name 2\t00008101-000123456789012E
/// # This is a comment
/// Device Name 3\t00008020-001A1B2C3D4E501F
/// ```
let registerFromFileLane = Lane(name: "register_from_file") {
    registerDevices(file: "devices.txt")

    // Optionally force profile regeneration
    match(
        type: .adhoc,
        appIdentifier: "com.example.app",
        forceForNewDevices: true
    )
}

/// Example 9: Register devices and sync for testing
///
/// Complete workflow for adding test devices and creating ad-hoc builds.
let addTestDevicesLane = Lane(name: "add_test_devices") {
    // Register new test devices
    registerDevices(devices: [
        "Tester iPhone": "00008030-001234567890401E",
        "Tester iPad": "00008101-000123456789012E"
    ])

    // Force regenerate ad-hoc profiles to include new devices
    match(
        type: .adhoc,
        appIdentifier: "com.example.app",
        forceForNewDevices: true
    )

    // Build ad-hoc IPA
    gym(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .adHoc
    )
}

// MARK: - CI/CD Examples

/// Example 10: CI workflow using environment variables
///
/// This lane is designed to run in CI environments where
/// all configuration is provided through environment variables.
///
/// Required environment variables:
/// - MATCH_PASSWORD: Encryption password for certificates
/// - MATCH_GIT_URL: Git repository URL for certificates
/// - MATCH_GIT_BRANCH: Git branch (defaults to "master")
/// - MATCH_TEAM_ID: Apple Developer Team ID
/// - MATCH_READONLY: Set to "true" for CI builds
/// - APP_STORE_CONNECT_API_KEY_ID: API key ID
/// - APP_STORE_CONNECT_API_ISSUER_ID: API issuer ID
/// - APP_STORE_CONNECT_API_KEY_PATH: Path to .p8 key file
let ciLane = Lane(name: "ci_build") {
    // Match uses environment variables automatically
    match(
        type: .appstore,
        appIdentifier: "com.example.app",
        readonly: true // Don't create new certificates in CI
    )

    // Run tests
    scan(
        scheme: "MyApp",
        devices: ["iPhone 15 Pro"],
        skipBuild: false
    )

    // Build for App Store
    gym(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .appStore,
        exportOptions: [
            "uploadBitcode": false,
            "uploadSymbols": true,
            "compileBitcode": false
        ]
    )
}

/// Example 11: CI workflow with manual configuration
///
/// Alternative CI workflow that explicitly sets configuration
/// instead of relying solely on environment variables.
let ciManualLane = Lane(name: "ci_manual") {
    // Explicit configuration (still requires MATCH_PASSWORD from environment)
    match(
        type: .appstore,
        appIdentifier: "com.example.app",
        teamId: "ABC123DEF4",
        gitUrl: "https://github.com/mycompany/certificates.git",
        branch: "main",
        readonly: true
    )

    gym(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .appStore
    )
}

/// Example 12: Beta distribution workflow
///
/// Complete workflow for TestFlight beta distribution.
let betaLane = Lane(name: "beta") {
    // Increment build number
    incrementBuildNumber()

    // Sync App Store certificates (readonly in CI)
    match(
        type: .appstore,
        appIdentifier: "com.example.app",
        readonly: true
    )

    // Build
    gym(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .appStore
    )

    // Upload to TestFlight (requires pilot action)
    // pilot(skipWaitingForBuildProcessing: true)
}

// MARK: - Enterprise Distribution Examples

/// Example 13: Enterprise distribution
///
/// Use enterprise certificates for in-house app distribution.
let enterpriseLane = Lane(name: "enterprise") {
    match(
        type: .enterprise,
        appIdentifier: "com.example.app"
    )

    gym(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .enterprise
    )
}

/// Example 14: Direct install enterprise build
///
/// Enterprise build with manifest for OTA installation.
let enterpriseOTALane = Lane(name: "enterprise_ota") {
    match(
        type: .enterprise,
        appIdentifier: "com.example.app"
    )

    gym(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .enterprise,
        exportOptions: [
            "manifest": [
                "appURL": "https://example.com/app.ipa",
                "displayImageURL": "https://example.com/icon.png",
                "fullSizeImageURL": "https://example.com/icon.png"
            ]
        ]
    )
}

// MARK: - Developer ID Examples

/// Example 15: Mac app with Developer ID
///
/// Sign macOS app for distribution outside the Mac App Store.
let macDeveloperIDLane = Lane(name: "mac_developer_id") {
    match(
        type: .developerID,
        appIdentifier: "com.example.macapp"
    )

    gym(
        scheme: "MyMacApp",
        configuration: .release,
        exportMethod: .developerID
    )
}

/// Example 16: Mac App Store distribution
///
/// Sign and package macOS app for Mac App Store submission.
let macAppStoreLane = Lane(name: "mac_appstore") {
    match(
        type: .macAppStore,
        appIdentifier: "com.example.macapp"
    )

    gym(
        scheme: "MyMacApp",
        configuration: .release,
        exportMethod: .macAppStore
    )
}

// MARK: - Complete Lanerfile Example

/// A complete Lanerfile demonstrating Match integration
struct MyLanerfile: Lanerfile {
    let lanes: [Lane] = [
        // Development
        developmentLane,

        // Release
        appStoreLane,
        betaLane,

        // Testing
        adHocLane,
        addTestDevicesLane,

        // CI/CD
        ciLane,

        // Device management
        registerDevicesLane,
        registerFromFileLane
    ]

    // Default lane
    var defaultLane: Lane {
        developmentLane
    }
}

// MARK: - Environment Variables Reference

/*
 # Match Environment Variables

 ## Required Variables

 MATCH_PASSWORD
   Description: Password used to encrypt/decrypt certificates and profiles
   Example: export MATCH_PASSWORD="my_secure_password"

 MATCH_GIT_URL
   Description: Git repository URL where certificates are stored
   Example: export MATCH_GIT_URL="https://github.com/company/certificates.git"

 ## Optional Variables

 MATCH_GIT_BRANCH
   Description: Git branch to use (defaults to "master")
   Example: export MATCH_GIT_BRANCH="develop"

 MATCH_TEAM_ID
   Description: Apple Developer Team ID
   Example: export MATCH_TEAM_ID="ABC123DEF4"

 MATCH_READONLY
   Description: Don't create new certificates/profiles (true/false, defaults to false)
   Example: export MATCH_READONLY="true"

 MATCH_FORCE_FOR_NEW_DEVICES
   Description: Force regenerate profiles when new devices added (true/false, defaults to false)
   Example: export MATCH_FORCE_FOR_NEW_DEVICES="true"

 MATCH_GIT_BASIC_AUTHORIZATION
   Description: Base64 encoded basic auth for Git (username:password)
   Example: export MATCH_GIT_BASIC_AUTHORIZATION="base64_encoded_credentials"

 ## App Store Connect API Variables

 APP_STORE_CONNECT_API_KEY_ID
   Description: App Store Connect API Key ID
   Example: export APP_STORE_CONNECT_API_KEY_ID="ABC123XYZ"

 APP_STORE_CONNECT_API_ISSUER_ID
   Description: App Store Connect API Issuer ID (UUID)
   Example: export APP_STORE_CONNECT_API_ISSUER_ID="12345678-1234-1234-1234-123456789012"

 APP_STORE_CONNECT_API_KEY_PATH
   Description: Path to .p8 private key file
   Example: export APP_STORE_CONNECT_API_KEY_PATH="/path/to/AuthKey_ABC123XYZ.p8"

 ## CI Environment Setup Example

 ```bash
 # .env.ci file
 export MATCH_PASSWORD="${MATCH_PASSWORD_SECRET}"
 export MATCH_GIT_URL="https://github.com/company/ios-certificates.git"
 export MATCH_GIT_BRANCH="main"
 export MATCH_TEAM_ID="ABC123DEF4"
 export MATCH_READONLY="true"
 export APP_STORE_CONNECT_API_KEY_ID="${ASC_KEY_ID}"
 export APP_STORE_CONNECT_API_ISSUER_ID="${ASC_ISSUER_ID}"
 export APP_STORE_CONNECT_API_KEY_PATH="./AuthKey.p8"
 ```

 ## GitHub Actions Example

 ```yaml
 - name: Setup Match environment
   run: |
     echo "${{ secrets.MATCH_P8_KEY }}" > AuthKey.p8
   env:
     MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
     MATCH_GIT_URL: https://github.com/company/certificates.git
     MATCH_TEAM_ID: ABC123DEF4
     MATCH_READONLY: true
     APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.ASC_KEY_ID }}
     APP_STORE_CONNECT_API_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
     APP_STORE_CONNECT_API_KEY_PATH: ./AuthKey.p8
 ```

 ## GitLab CI Example

 ```yaml
 variables:
   MATCH_PASSWORD: $MATCH_PASSWORD_SECRET
   MATCH_GIT_URL: "https://gitlab.com/company/ios-certificates.git"
   MATCH_GIT_BRANCH: "main"
   MATCH_TEAM_ID: "ABC123DEF4"
   MATCH_READONLY: "true"
   APP_STORE_CONNECT_API_KEY_ID: $ASC_KEY_ID
   APP_STORE_CONNECT_API_ISSUER_ID: $ASC_ISSUER_ID
   APP_STORE_CONNECT_API_KEY_PATH: "./AuthKey.p8"
 ```
*/
