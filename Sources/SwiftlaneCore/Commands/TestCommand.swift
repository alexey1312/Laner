import ArgumentParser
import Foundation
import Logging
import SwiftlaneKit

#if os(macOS)
/// Runs tests for an iOS/macOS project using xcodebuild.
public struct TestCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Run tests for an iOS or macOS project"
    )

    @OptionGroup var globalOptions: GlobalOptions

    @Option(name: .long, help: "Path to the workspace file (.xcworkspace)")
    var workspace: String?

    @Option(name: .long, help: "Path to the project file (.xcodeproj)")
    var project: String?

    @Option(name: [.short, .long], help: "The scheme to test")
    var scheme: String?

    @Option(name: [.short, .long], help: "Build configuration (Debug, Release)")
    var configuration: String = "Debug"

    @Option(name: .long, help: "Destination simulator (e.g., 'iPhone 15')")
    var simulator: String = "iPhone 15"

    @Option(name: .long, help: "Derived data path")
    var derivedDataPath: String?

    @Option(name: .long, help: "Only run specific test (e.g., 'MyTests/testFoo')")
    var only: String?

    @Flag(name: .long, help: "Retry failed tests")
    var retryFailed: Bool = false

    @Flag(name: .long, help: "Enable code coverage")
    var coverage: Bool = false

    public init() {}

    public func run() async throws {
        LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)
        let logger = Logger.swiftlane(.cli)

        logger.info("Starting tests...")

        // Discover workspace/project if not specified
        let (workspaceURL, projectURL) = try discoverProject()

        // Test options
        var options = TestOptions(configuration: configuration)

        if let workspaceURL = workspaceURL {
            options.workspace = workspaceURL.path(percentEncoded: false)
            logger.debug("Using workspace: \(workspaceURL.path)")
        } else if let projectURL = projectURL {
            options.project = projectURL.path(percentEncoded: false)
            logger.debug("Using project: \(projectURL.path)")
        }

        if let scheme = scheme {
            options.scheme = scheme
        } else {
            options.scheme = try await discoverScheme(workspace: workspaceURL, project: projectURL)
        }

        options.destination = "platform=iOS Simulator,name=\(simulator)"

        if let derivedDataPath = derivedDataPath {
            options.derivedDataPath = derivedDataPath
        }

        if let only = only {
            options.onlyTesting = [only]
        }

        // Note: coverage and retryFailed require enhanced TestOptions in the future
        _ = coverage
        _ = retryFailed

        logger.info("Testing scheme '\(options.scheme ?? "default")' on '\(simulator)'")

        // Execute tests
        let executor = XcodebuildExecutor()
        let result = try await executor.test(options: options)

        // Print results
        printTestResults(result, logger: logger)

        if !result.succeeded {
            throw ExitCode.failure
        }
    }

    private func printTestResults(_ result: TestResult, logger: Logger) {
        print("")
        print("Test Results")
        print("============")
        print("")

        let passedIcon = "✓"
        let failedIcon = "✗"

        print("Total: \(result.totalTests)")
        print("Passed: \(result.testsPassed)")
        print("Failed: \(result.testsFailed)")
        print("Skipped: \(result.testsSkipped)")
        print("Duration: \(formatDuration(result.duration))")

        if !result.failures.isEmpty {
            print("")
            print("Failed Tests:")
            for testName in result.failures {
                print("  \(failedIcon) \(testName)")
            }
        }

        print("")
        if result.succeeded {
            print("\(passedIcon) Tests passed")
        } else {
            print("\(failedIcon) Tests failed")
        }
    }

    private func formatDuration(_ duration: Duration) -> String {
        let totalSeconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        if totalSeconds < 60 {
            return String(format: "%.1fs", totalSeconds)
        }
        let minutes = Int(totalSeconds) / 60
        let secs = Int(totalSeconds) % 60
        return "\(minutes)m \(secs)s"
    }

    private func discoverProject() throws -> (workspace: URL?, project: URL?) {
        let workingDir = globalOptions.workingDirectoryURL
        let fileManager = FileManager.default

        if let workspace = workspace {
            return (URL(fileURLWithPath: workspace), nil)
        }

        if let project = project {
            return (nil, URL(fileURLWithPath: project))
        }

        let contents = try fileManager.contentsOfDirectory(atPath: workingDir.path(percentEncoded: false))

        if let workspaceName = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
            return (workingDir.appendingPathComponent(workspaceName), nil)
        }

        if let projectName = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
            return (nil, workingDir.appendingPathComponent(projectName))
        }

        throw CLIError.noProjectFound(in: workingDir)
    }

    private func discoverScheme(workspace: URL?, project: URL?) async throws -> String {
        let shell = ShellExecutor()
        var arguments = ["-list", "-json"]

        if let workspace = workspace {
            arguments += ["-workspace", workspace.path(percentEncoded: false)]
        } else if let project = project {
            arguments += ["-project", project.path(percentEncoded: false)]
        }

        let result = try await shell.run("xcodebuild", arguments: arguments)

        guard result.isSuccess else {
            throw CLIError.schemeDiscoveryFailed
        }

        guard let data = result.stdout.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CLIError.schemeDiscoveryFailed
        }

        if let workspaceInfo = json["workspace"] as? [String: Any],
           let schemes = workspaceInfo["schemes"] as? [String],
           let firstScheme = schemes.first {
            return firstScheme
        }

        if let projectInfo = json["project"] as? [String: Any],
           let schemes = projectInfo["schemes"] as? [String],
           let firstScheme = schemes.first {
            return firstScheme
        }

        throw CLIError.noSchemeFound
    }
}

#else
// Linux stub
public struct TestCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Run tests for an iOS or macOS project (macOS only)"
    )

    public init() {}

    public func run() throws {
        print("The test command is only available on macOS")
        throw ExitCode.failure
    }
}
#endif
