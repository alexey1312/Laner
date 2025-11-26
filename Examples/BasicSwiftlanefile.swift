// BasicSwiftlanefile.swift
// Example Swiftlane configuration file demonstrating basic usage.
//
// To use this file:
// 1. Copy it to your project root as `Swiftlanefile.swift`
// 2. Modify the lanes to match your workflow
// 3. Run lanes using the swiftlane CLI

import SwiftlaneDSL

/// Example Swiftlane configuration demonstrating common CI/CD patterns.
struct Swiftlanefile: SwiftlaneConfiguration {
    static var lanes: [Lane] {
        [
            buildLane,
            testLane,
            releaseLane,
        ]
    }

    // MARK: - Lanes

    /// Builds the project for development.
    static var buildLane: Lane {
        Lane(
            name: "build",
            description: "Build the app for development"
        ) { context in
            context.logger.info("Starting development build...")

            // Access environment variables
            let configuration = context.environment["BUILD_CONFIGURATION"] ?? "Debug"
            context.logger.info("Building with configuration: \(configuration)")

            // Run shell commands
            let result = try await context.shell.run(
                "xcodebuild",
                arguments: [
                    "-scheme", "App",
                    "-configuration", configuration,
                    "-destination", "generic/platform=iOS Simulator",
                    "build"
                ]
            )

            guard result.isSuccess else {
                throw SwiftlaneError.buildFailed(result.stderr)
            }

            context.logger.info("Build completed successfully!")
        }
    }

    /// Runs all tests.
    static var testLane: Lane {
        Lane(
            name: "test",
            description: "Run all unit and UI tests"
        ) { context in
            context.logger.info("Starting test run...")

            // Run tests using xcodebuild
            let result = try await context.shell.run(
                "xcodebuild",
                arguments: [
                    "-scheme", "App",
                    "-configuration", "Debug",
                    "-destination", "platform=iOS Simulator,name=iPhone 15",
                    "test"
                ]
            )

            guard result.isSuccess else {
                throw SwiftlaneError.testsFailed(result.stderr)
            }

            context.logger.info("All tests passed!")
        }
    }

    /// Creates a release build and archives it.
    static var releaseLane: Lane {
        Lane(
            name: "release",
            description: "Build and archive for release"
        ) { context in
            context.logger.info("Starting release build...")

            // Check we're in CI for release builds
            if context.environment.isCI {
                context.logger.info("Running in CI: \(context.environment.ciProvider?.rawValue ?? "Unknown")")
            } else {
                context.logger.warning("Not running in CI - consider using CI for releases")
            }

            // Archive
            let archivePath = "/tmp/App.xcarchive"
            let archiveResult = try await context.shell.run(
                "xcodebuild",
                arguments: [
                    "-scheme", "App",
                    "-configuration", "Release",
                    "-archivePath", archivePath,
                    "archive"
                ]
            )

            guard archiveResult.isSuccess else {
                throw SwiftlaneError.archiveFailed(archiveResult.stderr)
            }

            // Add artifact
            await context.addArtifact(
                Artifact(
                    type: .xcarchive,
                    path: URL(fileURLWithPath: archivePath),
                    name: "App Release Archive",
                    metadata: [
                        "configuration": "Release",
                        "date": ISO8601DateFormatter().string(from: Date())
                    ]
                )
            )

            context.logger.info("Release archive created at: \(archivePath)")
        }
    }

    // MARK: - Lifecycle Hooks

    static func beforeAll(lane: Lane) async {
        print("[Swiftlanefile] Starting lane: \(lane.name)")
    }

    static func afterAll(lane: Lane, result: LaneResult) async {
        if result.success {
            print("[Swiftlanefile] Lane '\(lane.name)' completed in \(result.duration.formatted())")
        } else {
            print("[Swiftlanefile] Lane '\(lane.name)' failed!")
        }
    }

    static func onError(lane: Lane, error: any Error) async {
        print("[Swiftlanefile] Error in '\(lane.name)': \(error.localizedDescription)")
    }
}

// MARK: - Custom Errors

enum SwiftlaneError: Error, LocalizedError {
    case buildFailed(String)
    case testsFailed(String)
    case archiveFailed(String)

    var errorDescription: String? {
        switch self {
        case .buildFailed(let reason):
            return "Build failed: \(reason)"
        case .testsFailed(let reason):
            return "Tests failed: \(reason)"
        case .archiveFailed(let reason):
            return "Archive failed: \(reason)"
        }
    }
}

// MARK: - Duration Formatting Helper

extension Duration {
    func formatted() -> String {
        let totalSeconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        if totalSeconds < 60 {
            return String(format: "%.1fs", totalSeconds)
        }
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return "\(minutes)m \(seconds)s"
    }
}
