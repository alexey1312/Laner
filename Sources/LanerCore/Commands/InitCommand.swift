import ArgumentParser
import Foundation
import Logging
import LanerKit

/// Initializes a new Laner project by creating the configuration directory and template file.
public struct InitCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Initialize a new Laner project"
    )

    @OptionGroup var globalOptions: GlobalOptions

    @Flag(name: .long, help: "Overwrite existing Lanerfile.swift")
    var force: Bool = false

    public init() {}

    public func run() async throws {
        LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)
        let logger = Logger.laner(.cli)

        let fileManager = FileManager.default
        let workingDir = globalOptions.workingDirectoryURL
        let lanerDir = workingDir.appendingPathComponent("Laner")
        let lanerfilePath = lanerDir.appendingPathComponent("Lanerfile.swift")

        logger.info("Initializing Laner project in \(workingDir.path(percentEncoded: false))")

        // Check if Laner directory exists
        var isDirectory: ObjCBool = false
        let lanerDirExists = fileManager.fileExists(
            atPath: lanerDir.path(percentEncoded: false),
            isDirectory: &isDirectory
        )

        if lanerDirExists && isDirectory.boolValue {
            logger.debug("Laner/ directory already exists")
        }

        // Check if Lanerfile.swift exists
        var isFile: ObjCBool = false
        let lanerfileExists = fileManager.fileExists(
            atPath: lanerfilePath.path(percentEncoded: false),
            isDirectory: &isFile
        )

        if lanerfileExists && !force {
            logger.error("Lanerfile.swift already exists")
            print("Error: Lanerfile.swift already exists. Use --force to overwrite.")
            throw ExitCode.failure
        }

        // Create Laner directory if needed
        if !lanerDirExists {
            do {
                try fileManager.createDirectory(
                    at: lanerDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                logger.debug("Created Laner/ directory")
            } catch {
                logger.error("Failed to create Laner/ directory: \(error)")
                throw CLIError.invalidArgument("Failed to create Laner/ directory: \(error.localizedDescription)")
            }
        }

        // Generate Lanerfile.swift template
        let template = generateLanerfileTemplate()

        do {
            try template.write(to: lanerfilePath, atomically: true, encoding: .utf8)
            logger.info("Created Lanerfile.swift")
        } catch {
            logger.error("Failed to write Lanerfile.swift: \(error)")
            throw CLIError.invalidArgument("Failed to write Lanerfile.swift: \(error.localizedDescription)")
        }

        // Print success message
        print("Created Laner/Lanerfile.swift")
        print("Run 'laner lanes' to see available lanes")
    }

    /// Generates the Lanerfile.swift template content.
    private func generateLanerfileTemplate() -> String {
        return """
        // Laner/Lanerfile.swift
        import LanerDSL

        let laner = Lanerfile(
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
