import ArgumentParser
import Foundation
import LanerKit
import Logging

/// Initializes a new Laner project by creating the Pkl manifest and schema.
public struct InitCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Initialize a new Laner project"
    )

    @OptionGroup var globalOptions: GlobalOptions

    @Flag(name: .long, help: "Overwrite existing Lanerfile.pkl")
    var force: Bool = false

    public init() {}

    public func run() async throws {
        LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)
        let logger = Logger.laner(.cli)

        let fileManager = FileManager.default
        let workingDir = globalOptions.workingDirectoryURL
        let lanerDir = workingDir.appendingPathComponent("Laner")
        let lanerfilePath = lanerDir.appendingPathComponent("Lanerfile.pkl")
        let pklDir = lanerDir.appendingPathComponent("pkl")
        let schemaPath = pklDir.appendingPathComponent("Lanerfile.pkl")

        logger.info("Initializing Laner project in \(workingDir.path(percentEncoded: false))")

        // Check if Lanerfile.pkl exists
        var isDirectory: ObjCBool = false
        let lanerfileExists = fileManager.fileExists(
            atPath: lanerfilePath.path(percentEncoded: false),
            isDirectory: &isDirectory
        )

        if lanerfileExists, !force {
            logger.error("Lanerfile.pkl already exists")
            print("Error: Lanerfile.pkl already exists. Use --force to overwrite.")
            throw ExitCode.failure
        }

        // Create directories
        do {
            try fileManager.createDirectory(
                at: pklDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.debug("Created Laner/pkl/ directory")
        } catch {
            logger.error("Failed to create directories: \(error)")
            throw CLIError.invalidArgument("Failed to create Laner/ directory: \(error.localizedDescription)")
        }

        // Copy bundled Pkl schema to user project
        try copyBundledSchema(to: schemaPath, logger: logger)

        // Generate Lanerfile.pkl template
        let template = generateLanerfileTemplate()

        do {
            try template.write(to: lanerfilePath, atomically: true, encoding: .utf8)
            logger.info("Created Lanerfile.pkl")
        } catch {
            logger.error("Failed to write Lanerfile.pkl: \(error)")
            throw CLIError.invalidArgument("Failed to write Lanerfile.pkl: \(error.localizedDescription)")
        }

        print("Created Laner/Lanerfile.pkl")
        print("Created Laner/pkl/Lanerfile.pkl (schema)")
        print("Run 'laner lanes' to see available lanes")
    }

    /// Copies the bundled Pkl schema from LanerDSL resources to the user's project.
    private func copyBundledSchema(to destination: URL, logger: Logger) throws {
        guard let bundledSchemaURL = Bundle.module(for: "LanerDSL")?.url(
            forResource: "Lanerfile",
            withExtension: "pkl",
            subdirectory: "pkl"
        ) else {
            // Fallback: write the schema inline if bundle resource is not found
            logger.warning("Bundled schema not found, writing inline schema")
            let schema = generateSchemaContent()
            try schema.write(to: destination, atomically: true, encoding: .utf8)
            return
        }

        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false), isDirectory: &isDir) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: bundledSchemaURL, to: destination)
        logger.debug("Copied bundled schema to \(destination.path(percentEncoded: false))")
    }

    /// Generates the Lanerfile.pkl template content.
    private func generateLanerfileTemplate() -> String {
        """
        amends "pkl/Lanerfile.pkl"

        lanes {
          new {
            name = "build"
            description = "Build the app"
            actions {
              new GymAction {
                scheme = "App"
              }
            }
          }

          new {
            name = "test"
            description = "Run tests"
            actions {
              new ScanAction {
                scheme = "App"
                codeCoverage = true
              }
            }
          }

          new {
            name = "release"
            description = "Build and archive for release"
            actions {
              new GymAction {
                scheme = "App"
                configuration = "release"
              }
              new ArchiveAction {
                scheme = "App"
                exportMethod = "app-store"
              }
            }
          }
        }
        """
    }

    /// Generates the Pkl schema content (fallback when bundle resource is unavailable).
    private func generateSchemaContent() -> String { // swiftlint:disable:this function_body_length
        """
        /// Laner CI/CD pipeline configuration.
        ///
        /// This module defines the schema for Lanerfile.pkl files.
        /// Users amend this module to define their CI/CD lanes and actions.
        ///
        /// Example:
        /// ```pkl
        /// amends "pkl/Lanerfile.pkl"
        ///
        /// lanes {
        ///   new { name = "build"; actions { new GymAction { scheme = "App" } } }
        /// }
        /// ```
        module Lanerfile

        /// Build configuration for Xcode projects.
        typealias BuildConfiguration = "debug"|"release"

        /// Export method for archive actions.
        typealias ExportMethod = "app-store"|"ad-hoc"|"development"|"enterprise"

        /// Certificate type for code signing.
        typealias CertificateType = "development"|"distribution"|"adhoc"|"appstore"

        /// Device platform for registration.
        typealias DevicePlatform = "iOS"|"macOS"|"tvOS"|"watchOS"|"visionOS"

        /// Base class for all pipeline actions.
        open class Action {
          /// Discriminator for action dispatch.
          fixed type: String
        }

        /// Builds an iOS/macOS app using xcodebuild.
        class GymAction extends Action {
          fixed type = "gym"
          /// The Xcode scheme to build.
          scheme: String
          /// The workspace file path.
          workspace: String?
          /// The project file path.
          project: String?
          /// The build configuration.
          configuration: BuildConfiguration = "debug"
          /// The build destination.
          destination: String?
        }

        /// Runs tests using xcodebuild.
        class ScanAction extends Action {
          fixed type = "scan"
          /// The Xcode scheme to test.
          scheme: String
          /// The workspace file path.
          workspace: String?
          /// Devices to run tests on.
          devices: Listing<String>?
          /// Whether to enable code coverage.
          codeCoverage: Boolean = false
        }

        /// Archives an app and exports an IPA.
        class ArchiveAction extends Action {
          fixed type = "archive"
          /// The Xcode scheme to archive.
          scheme: String
          /// The build configuration.
          configuration: BuildConfiguration = "release"
          /// The export method.
          exportMethod: ExportMethod = "app-store"
        }

        /// Syncs code signing certificates and provisioning profiles.
        class MatchAction extends Action {
          fixed type = "match"
          /// The certificate type to sync.
          certificateType: CertificateType
          /// Whether to run in readonly mode.
          readonly: Boolean = false
          /// App identifier to sync profiles for.
          appIdentifier: String?
          /// Team ID for code signing.
          teamId: String?
          /// Git repository URL for certificate storage.
          gitUrl: String?
          /// Force regenerate profiles when new devices are added.
          forceForNewDevices: Boolean = false
          /// Git branch to use.
          branch: String = "master"
          /// Encryption password for certificates.
          password: String?
        }

        /// Uploads a build to TestFlight.
        class PilotAction extends Action {
          fixed type = "pilot"
          /// Path to the IPA file to upload.
          ipa: String?
          /// The App Store Connect app ID.
          appId: String?
          /// Release notes for TestFlight testers.
          changelog: String?
          /// Names of beta groups to distribute to.
          groups: Listing<String>?
          /// Skip waiting for Apple to process the build.
          skipWaitingForProcessing: Boolean = true
        }

        /// Registers devices with Apple Developer Portal.
        class RegisterDevicesAction extends Action {
          fixed type = "register_devices"
          /// Path to a file containing device names and UDIDs.
          file: String?
          /// Dictionary of device name to UDID mappings.
          devices: Mapping<String, String>?
          /// Platform for the devices.
          platform: DevicePlatform = "iOS"
          /// Team ID for device registration.
          teamId: String?
          /// App Store Connect API key ID.
          apiKeyId: String?
          /// App Store Connect API issuer ID.
          apiIssuerId: String?
          /// Path to App Store Connect API private key (.p8).
          apiKeyPath: String?
        }

        /// Executes an arbitrary shell command.
        class ShellAction extends Action {
          fixed type = "shell"
          /// The command to execute.
          command: String
          /// Arguments to pass to the command.
          arguments: Listing<String> = new {}
        }

        /// A named sequence of actions in a CI/CD pipeline.
        class Lane {
          /// The unique name of this lane.
          name: String
          /// A human-readable description of what this lane does.
          description: String = ""
          /// The actions to execute in order.
          actions: Listing<Action>
        }

        /// The lanes defined in this configuration.
        lanes: Listing<Lane>
        """
    }
}

// MARK: - Bundle Helper

private extension Bundle {
    /// Attempts to locate the resource bundle for a given module name.
    static func module(for moduleName: String) -> Bundle? {
        // Check in the main bundle's resource path
        let bundleName = "\(moduleName)_\(moduleName)"
        if let url = Bundle.main.url(forResource: bundleName, withExtension: "bundle"),
           let bundle = Bundle(url: url)
        {
            return bundle
        }

        // Check relative to the executable
        #if DEBUG
            // During development, SPM resources are in the build directory
            let executableURL = Bundle.main.bundleURL
            let resourceURL = executableURL
                .appendingPathComponent("\(bundleName).bundle")
            if let bundle = Bundle(url: resourceURL) {
                return bundle
            }
        #endif

        return nil
    }
}
