import ArgumentParser
import Foundation
import Logging
import SwiftlaneKit

#if os(macOS)
/// Builds an iOS/macOS project using xcodebuild.
public struct BuildCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build an iOS or macOS project"
    )

    @OptionGroup var globalOptions: GlobalOptions

    @Option(name: .long, help: "Path to the workspace file (.xcworkspace)")
    var workspace: String?

    @Option(name: .long, help: "Path to the project file (.xcodeproj)")
    var project: String?

    @Option(name: [.short, .long], help: "The scheme to build")
    var scheme: String?

    @Option(name: [.short, .long], help: "Build configuration (Debug, Release)")
    var configuration: String = "Debug"

    @Option(name: .long, help: "Destination simulator (e.g., 'iPhone 15')")
    var simulator: String?

    @Option(name: .long, help: "Derived data path")
    var derivedDataPath: String?

    @Flag(name: .long, help: "Clean before building")
    var clean: Bool = false

    public init() {}

    public func run() async throws {
        LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)
        let logger = Logger.swiftlane(.cli)

        logger.info("Starting build...")

        // Discover workspace/project if not specified
        let (workspaceURL, projectURL) = try discoverProject()

        // Build options
        var options = BuildOptions(configuration: configuration)

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
            // Try to discover scheme
            options.scheme = try await discoverScheme(workspace: workspaceURL, project: projectURL)
        }

        if let simulator = simulator {
            options.destination = "platform=iOS Simulator,name=\(simulator)"
        }

        if let derivedDataPath = derivedDataPath {
            options.derivedDataPath = derivedDataPath
        }

        options.clean = clean

        logger.info("Building scheme '\(options.scheme ?? "default")' with configuration '\(configuration)'")

        // Execute build
        let executor = XcodebuildExecutor()
        let result = try await executor.build(options: options)

        if result.succeeded {
            logger.info("Build succeeded in \(formatDuration(result.duration))")
            print("✓ Build succeeded")
        } else {
            logger.error("Build failed")
            print("✗ Build failed")
            if !result.errors.isEmpty {
                print("")
                print("Errors:")
                for error in result.errors {
                    print("  • \(error)")
                }
            }
            throw ExitCode.failure
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

        // Check if workspace or project specified
        if let workspace = workspace {
            return (URL(fileURLWithPath: workspace), nil)
        }

        if let project = project {
            return (nil, URL(fileURLWithPath: project))
        }

        // Auto-discover
        let contents = try fileManager.contentsOfDirectory(atPath: workingDir.path(percentEncoded: false))

        // Prefer workspace over project
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

        // Parse JSON output
        guard let data = result.stdout.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CLIError.schemeDiscoveryFailed
        }

        // Extract schemes
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
public struct BuildCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build an iOS or macOS project (macOS only)"
    )

    public init() {}

    public func run() throws {
        print("The build command is only available on macOS")
        throw ExitCode.failure
    }
}
#endif
