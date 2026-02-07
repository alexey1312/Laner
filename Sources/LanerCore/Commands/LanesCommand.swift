import ArgumentParser
import Foundation
import LanerDSL
import LanerKit
import Logging

/// Lists all available lanes defined in the Lanerfile.pkl.
///
/// This command discovers and displays lane metadata without executing them.
/// Use `laner lane <name>` to execute a specific lane.
public struct LanesCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "lanes",
        abstract: "List available lanes"
    )

    @OptionGroup var globalOptions: GlobalOptions

    public init() {}

    public func run() async throws {
        LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)
        let logger = Logger.laner(.cli)

        let workingDir = globalOptions.workingDirectoryURL
        let loader = ManifestLoader()

        // Check if manifest exists
        guard loader.manifestExists(in: workingDir) else {
            logger.error("No Lanerfile.pkl found")
            print("Error: No Lanerfile.pkl found. Run 'laner init' to create one.")
            throw ExitCode.failure
        }

        // Load the manifest
        logger.debug("Loading manifest from: \(workingDir.path)")
        let manifest: Lanerfile.Module
        do {
            manifest = try await loader.load(from: workingDir)
        } catch let error as ManifestError {
            switch error {
            case .notFound:
                print("Error: Lanerfile.pkl not found.")
                print("Run 'laner init' to create a new manifest.")
                throw ExitCode.failure
            case let .evaluationFailed(details):
                print("Error: Failed to evaluate Lanerfile.pkl")
                print("")
                print(details)
                throw ExitCode.failure
            case let .versionMismatch(expected, found):
                print("Error: DSL version mismatch")
                print("Binary version: \(expected), bundled DSL version: \(found)")
                print("Please reinstall Laner to fix this issue.")
                throw ExitCode.failure
            }
        }

        // Display available lanes
        if manifest.lanes.isEmpty {
            print("No lanes defined in Lanerfile.pkl")
            return
        }

        print("Available lanes:")
        for lane in manifest.lanes {
            if lane.description.isEmpty {
                print("  \(lane.name)")
            } else {
                print("  \(lane.name) - \(lane.description)")
            }
        }
    }
}
