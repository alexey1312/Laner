import ArgumentParser
import Foundation
import LanerDSL
import LanerKit
import Logging

/// Executes a named lane from the Lanerfile.
///
/// This command loads the manifest, finds the requested lane by name,
/// and executes it using a `LaneRunner`. It provides formatted output
/// showing execution progress and results.
///
/// ## Example
/// ```bash
/// $ laner lane build
/// Running lane 'build'...
/// Lane 'build' completed in 45.2s
/// ```
public struct LaneCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "lane",
        abstract: "Execute a lane"
    )

    @OptionGroup var globalOptions: GlobalOptions

    @Argument(help: "The name of the lane to execute")
    var laneName: String

    public init() {}

    public func run() async throws {
        LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)
        let logger = Logger.laner(.cli)

        let directory = globalOptions.workingDirectoryURL
        logger.debug("Working directory: \(directory.path(percentEncoded: false))")

        // Load manifest
        logger.debug("Loading manifest...")
        let loader = ManifestLoader(logger: logger)

        let manifest: Lanerfile
        do {
            manifest = try await loader.load(from: directory)
        } catch let error as ManifestError {
            // Handle manifest-specific errors with user-friendly messages
            switch error {
            case .notFound:
                print("Error: Lanerfile.swift not found.")
                print("Run 'laner init' to create a new manifest.")
                throw ExitCode.failure
            case let .compilationFailed(output):
                print("Error: Failed to compile Lanerfile.swift")
                print("")
                print(output)
                throw ExitCode.failure
            case let .executionFailed(output):
                print("Error: Failed to execute manifest")
                print("")
                print(output)
                throw ExitCode.failure
            case let .invalidOutput(details):
                print("Error: Invalid manifest output")
                print(details)
                throw ExitCode.failure
            case .installPathNotFound:
                print("Error: Could not determine Laner installation path")
                print("Ensure Laner is properly installed with lib/laner/ directory.")
                throw ExitCode.failure
            case let .versionMismatch(expected, found):
                print("Error: DSL version mismatch")
                print("Binary version: \(expected), bundled DSL version: \(found)")
                print("Please reinstall Laner to fix this issue.")
                throw ExitCode.failure
            }
        }

        // Find lane
        guard let lane = manifest.lane(named: laneName) else {
            logger.error("Lane '\(laneName)' not found")
            print("Error: Lane '\(laneName)' not found. Run 'laner lanes' to see available lanes.")
            throw ExitCode.failure
        }

        logger.info("Executing lane: \(laneName)")

        // Execute lane
        print("Running lane '\(laneName)'...")

        // Create runner and execute on MainActor
        let runner = LaneRunner(logger: logger)
        let result = await Self.executeOnMainActor(lane: lane, runner: runner, logger: logger, directory: directory)

        // Print result
        if result.success {
            let formattedDuration = result.duration.formatted()
            logger.info("Lane '\(laneName)' completed successfully in \(formattedDuration)")
            print("Lane '\(laneName)' completed in \(formattedDuration)")

            // Print artifacts if any
            if !result.artifacts.isEmpty {
                print("")
                print("Artifacts:")
                for artifact in result.artifacts {
                    print("  • \(artifact.type): \(artifact.path.path(percentEncoded: false))")
                }
            }
        } else {
            logger.error("Lane '\(laneName)' failed")
            print("Lane '\(laneName)' failed")

            if let error = result.error {
                print("")
                print("Error: \(error.localizedDescription)")
            }

            throw ExitCode.failure
        }
    }

    /// Executes a lane on the MainActor.
    /// - Parameters:
    ///   - lane: The lane to execute.
    ///   - runner: The lane runner.
    ///   - logger: The logger for execution.
    ///   - directory: The working directory.
    /// - Returns: The execution result.
    @MainActor
    private static func executeOnMainActor(
        lane: Lane,
        runner: LaneRunner,
        logger: Logger,
        directory: URL
    ) async -> LaneResult {
        let context = ExecutionContext(
            logger: logger,
            workingDirectory: directory
        )
        return await runner.run(lane, context: context)
    }
}
