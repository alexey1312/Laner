import LanerDSL

/// Example demonstrating the gym(), scan(), and archive() DSL action functions.
///
/// These placeholder actions will be replaced with actual implementations that
/// execute xcodebuild commands.

// MARK: - Basic Usage

/// Example lane using gym() to build an app
let buildLane = Lane("build", description: "Build the iOS app") {
    gym(
        scheme: "MyApp",
        workspace: "MyApp.xcworkspace",
        configuration: .debug,
        destination: "generic/platform=iOS"
    )
}

/// Example lane using scan() to run tests
let testLane = Lane("test", description: "Run unit and UI tests") {
    scan(
        scheme: "MyApp",
        workspace: "MyApp.xcworkspace",
        devices: ["iPhone 15 Pro", "iPad Pro"],
        codeCoverage: true
    )
}

/// Example lane using archive() to create an IPA
let releaseLane = Lane("release", description: "Archive and export IPA") {
    archive(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .appStore
    )
}

// MARK: - Combined Workflows

/// Example lane combining multiple actions
let fullPipelineLane = Lane("pipeline", description: "Full CI/CD pipeline") {
    // Build in debug mode
    gym(
        scheme: "MyApp",
        workspace: "MyApp.xcworkspace",
        configuration: .debug
    )

    // Run tests with coverage
    scan(
        scheme: "MyApp",
        workspace: "MyApp.xcworkspace",
        codeCoverage: true
    )

    // Archive for App Store
    archive(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .appStore
    )
}

// MARK: - Different Export Methods

/// Archive for ad-hoc distribution
let adHocLane = Lane("adhoc", description: "Build ad-hoc distribution") {
    archive(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .adHoc
    )
}

/// Archive for development
let devLane = Lane("dev", description: "Build development version") {
    archive(
        scheme: "MyApp",
        configuration: .debug,
        exportMethod: .development
    )
}

/// Archive for enterprise distribution
let enterpriseLane = Lane("enterprise", description: "Build enterprise distribution") {
    archive(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .enterprise
    )
}

// MARK: - Conditional Execution

/// Example with conditional test execution
struct ExampleConfig: LanerConfiguration {
    static var lanes: [Lane] {
        [
            Lane("ci", description: "CI pipeline") {
                // Always build
                gym(
                    scheme: "MyApp",
                    workspace: "MyApp.xcworkspace",
                    configuration: .debug
                )

                // Run tests only on CI
                // Note: In real usage, you'd check the environment
                scan(
                    scheme: "MyApp",
                    workspace: "MyApp.xcworkspace",
                    codeCoverage: true
                )
            }
        ]
    }
}
