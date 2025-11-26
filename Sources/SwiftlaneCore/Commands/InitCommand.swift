import ArgumentParser
import Foundation
import Logging
import SwiftlaneKit

/// Initializes a new Swiftlane project by creating the configuration directory and template file.
public struct InitCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Initialize a new Swiftlane project"
    )

    @OptionGroup var globalOptions: GlobalOptions

    @Flag(name: .long, help: "Overwrite existing Swiftlanefile.swift")
    var force: Bool = false

    public init() {}

    public func run() async throws {
        LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)
        let logger = Logger.swiftlane(.cli)

        let fileManager = FileManager.default
        let workingDir = globalOptions.workingDirectoryURL
        let swiftlaneDir = workingDir.appendingPathComponent("Swiftlane")
        let swiftlanefilePath = swiftlaneDir.appendingPathComponent("Swiftlanefile.swift")

        logger.info("Initializing Swiftlane project in \(workingDir.path(percentEncoded: false))")

        // Check if Swiftlane directory exists
        var isDirectory: ObjCBool = false
        let swiftlaneDirExists = fileManager.fileExists(
            atPath: swiftlaneDir.path(percentEncoded: false),
            isDirectory: &isDirectory
        )

        if swiftlaneDirExists && isDirectory.boolValue {
            logger.debug("Swiftlane/ directory already exists")
        }

        // Check if Swiftlanefile.swift exists
        var isFile: ObjCBool = false
        let swiftlanefileExists = fileManager.fileExists(
            atPath: swiftlanefilePath.path(percentEncoded: false),
            isDirectory: &isFile
        )

        if swiftlanefileExists && !force {
            logger.error("Swiftlanefile.swift already exists")
            print("Error: Swiftlanefile.swift already exists. Use --force to overwrite.")
            throw ExitCode.failure
        }

        // Create Swiftlane directory if needed
        if !swiftlaneDirExists {
            do {
                try fileManager.createDirectory(
                    at: swiftlaneDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                logger.debug("Created Swiftlane/ directory")
            } catch {
                logger.error("Failed to create Swiftlane/ directory: \(error)")
                throw CLIError.invalidArgument("Failed to create Swiftlane/ directory: \(error.localizedDescription)")
            }
        }

        // Generate Swiftlanefile.swift template
        let template = generateSwiftlanefileTemplate()

        do {
            try template.write(to: swiftlanefilePath, atomically: true, encoding: .utf8)
            logger.info("Created Swiftlanefile.swift")
        } catch {
            logger.error("Failed to write Swiftlanefile.swift: \(error)")
            throw CLIError.invalidArgument("Failed to write Swiftlanefile.swift: \(error.localizedDescription)")
        }

        // Print success message
        print("Created Swiftlane/Swiftlanefile.swift")
        print("Run 'swiftlane lanes' to see available lanes")
    }

    /// Generates the Swiftlanefile.swift template content.
    private func generateSwiftlanefileTemplate() -> String {
        return """
        // Swiftlane/Swiftlanefile.swift
        import SwiftlaneDSL

        let swiftlane = Swiftlanefile(
            lanes: [
                Lane("build") {
                    gym(scheme: "App", configuration: .debug)
                },

                Lane("test") {
                    scan(scheme: "AppTests", codeCoverage: true)
                },

                Lane("release") {
                    gym(scheme: "App", configuration: .release)
                    archive(scheme: "App", exportMethod: .appStore)
                }
            ]
        )
        """
    }
}
