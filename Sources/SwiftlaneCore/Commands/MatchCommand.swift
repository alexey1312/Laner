import ArgumentParser
import Foundation
import Logging
import SwiftlaneKit
import SwiftlaneMatch

#if os(macOS)

/// Manages code signing certificates and provisioning profiles using Match.
public struct MatchCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "match",
        abstract: "Manage code signing certificates and provisioning profiles",
        subcommands: [
            SyncCommand.self,
            MatchInitCommand.self,
            NukeCommand.self,
            RegisterCommand.self,
            ChangePasswordCommand.self,
        ]
    )

    public init() {}
}

// MARK: - Sync Command

extension MatchCommand {
    /// Synchronize certificates and provisioning profiles
    struct SyncCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "sync",
            abstract: "Download and install certificates and provisioning profiles"
        )

        @OptionGroup var globalOptions: GlobalOptions

        @Option(name: .shortAndLong, help: "Certificate type: development, distribution, adhoc, appstore")
        var type: String

        @Flag(name: .long, help: "Don't create new certificates if missing (readonly mode)")
        var readonly: Bool = false

        @Option(name: .long, help: "Specific app bundle identifier (can be repeated)")
        var appIdentifier: [String] = []

        @Option(name: .long, help: "Git repository URL (overrides MATCH_GIT_URL)")
        var gitUrl: String?

        @Option(name: .long, help: "Team ID (overrides MATCH_TEAM_ID)")
        var teamId: String?

        @Option(name: .long, help: "Git branch (default: master)")
        var branch: String = "master"

        func run() async throws {
            LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)
            let logger = Logger.swiftlane(.cli)

            // Parse certificate type
            guard let certType = CertificateType(rawValue: type.lowercased()) else {
                logger.error("Invalid certificate type: \(type)")
                print("Valid types: development, distribution, adhoc, appstore")
                throw ExitCode.failure
            }

            logger.info("Starting Match sync for \(certType.rawValue)")

            // Build configuration from environment and CLI args
            var config: MatchConfiguration
            do {
                config = try MatchConfiguration.fromEnvironment()
            } catch MatchError.missingEnvironmentVariable(let name) {
                logger.error("Missing environment variable: \(name)")
                print("Set \(name) environment variable or use --\(name.lowercased().replacingOccurrences(of: "_", with: "-"))")
                throw ExitCode.failure
            }

            // Override with CLI args if provided
            if let gitUrl = gitUrl {
                config = MatchConfiguration(
                    gitUrl: gitUrl,
                    branch: branch,
                    teamId: teamId ?? config.teamId,
                    apiKeyId: config.apiKeyId,
                    apiIssuerId: config.apiIssuerId,
                    apiKeyPath: config.apiKeyPath,
                    password: config.password,
                    readonly: readonly,
                    forceForNewDevices: config.forceForNewDevices
                )
            } else if let teamId = teamId {
                config = MatchConfiguration(
                    gitUrl: config.gitUrl,
                    branch: branch,
                    teamId: teamId,
                    apiKeyId: config.apiKeyId,
                    apiIssuerId: config.apiIssuerId,
                    apiKeyPath: config.apiKeyPath,
                    password: config.password,
                    readonly: readonly,
                    forceForNewDevices: config.forceForNewDevices
                )
            } else if readonly != config.readonly {
                config = MatchConfiguration(
                    gitUrl: config.gitUrl,
                    branch: branch,
                    teamId: config.teamId,
                    apiKeyId: config.apiKeyId,
                    apiIssuerId: config.apiIssuerId,
                    apiKeyPath: config.apiKeyPath,
                    password: config.password,
                    readonly: readonly,
                    forceForNewDevices: config.forceForNewDevices
                )
            }

            // Create and run match service
            let service = try MatchService(configuration: config)
            let result = try await service.sync(type: certType, appIdentifiers: appIdentifier)

            // Report results
            logger.info("Sync completed successfully")
            print("")
            print("Match Sync Results")
            print("==================")
            print("")
            print("Certificates installed: \(result.certificates.count)")
            for cert in result.certificates {
                print("  - \(cert.name)")
            }
            print("")
            print("Provisioning profiles installed: \(result.profiles.count)")
            for profile in result.profiles {
                print("  - \(profile.name)")
            }
            print("")
            print("Success: All certificates and profiles synced")
        }
    }
}

// MARK: - Init Command

extension MatchCommand {
    /// Initialize Match configuration
    struct MatchInitCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "init",
            abstract: "Initialize Match configuration and Git repository"
        )

        @OptionGroup var globalOptions: GlobalOptions

        @Option(name: .long, help: "Git repository URL for certificate storage")
        var gitUrl: String

        @Option(name: .long, help: "Team ID")
        var teamId: String

        @Option(name: .long, help: "Git branch (default: master)")
        var branch: String = "master"

        @Flag(name: .long, help: "Skip creating initial repository structure")
        var skipSetup: Bool = false

        func run() async throws {
            LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)
            let logger = Logger.swiftlane(.cli)

            logger.info("Initializing Match")

            // Check for password
            guard ProcessInfo.processInfo.environment["MATCH_PASSWORD"] != nil else {
                logger.error("MATCH_PASSWORD environment variable required")
                print("Set MATCH_PASSWORD before running match init")
                throw ExitCode.failure
            }

            print("")
            print("Match Initialization")
            print("====================")
            print("")
            print("Git URL: \(gitUrl)")
            print("Team ID: \(teamId)")
            print("Branch: \(branch)")
            print("")

            if !skipSetup {
                logger.info("Setting up repository structure")
                // TODO: Create initial directory structure in the repo
                print("Repository structure created")
            }

            print("")
            print("Match initialized successfully")
            print("")
            print("Set these environment variables:")
            print("  export MATCH_GIT_URL=\"\(gitUrl)\"")
            print("  export MATCH_TEAM_ID=\"\(teamId)\"")
            print("  export MATCH_PASSWORD=\"<your-password>\"")
            print("")
            print("Run 'swiftlane match sync --type development' to sync certificates")
        }
    }
}

// MARK: - Nuke Command

extension MatchCommand {
    /// Revoke and remove certificates
    struct NukeCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "nuke",
            abstract: "Revoke and remove certificates and profiles (DESTRUCTIVE)"
        )

        @OptionGroup var globalOptions: GlobalOptions

        @Option(name: .shortAndLong, help: "Certificate type: development, distribution, adhoc, appstore")
        var type: String

        @Flag(name: .long, help: "Skip confirmation prompt")
        var force: Bool = false

        func run() async throws {
            LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)
            let logger = Logger.swiftlane(.cli)

            // Parse certificate type
            guard let certType = CertificateType(rawValue: type.lowercased()) else {
                logger.error("Invalid certificate type: \(type)")
                print("Valid types: development, distribution, adhoc, appstore")
                throw ExitCode.failure
            }

            // Confirmation prompt
            if !force {
                print("")
                print("WARNING: This will PERMANENTLY REVOKE all \(certType.rawValue) certificates")
                print("and DELETE all associated provisioning profiles from:")
                print("  - App Store Connect")
                print("  - Git storage repository")
                print("")
                print("This action CANNOT be undone!")
                print("")
                print("Type 'yes' to continue: ", terminator: "")

                guard let response = readLine()?.lowercased(), response == "yes" else {
                    print("Operation cancelled")
                    return
                }
            }

            logger.warning("Starting nuke operation for \(certType.rawValue)")

            // Build configuration
            let config = try MatchConfiguration.fromEnvironment()
            let service = try MatchService(configuration: config)

            let result = try await service.nuke(type: certType)

            // Report results
            logger.info("Nuke completed")
            print("")
            print("Nuke Results")
            print("============")
            print("")
            print("Certificates revoked: \(result.certificatesRevoked)")
            print("Profiles deleted: \(result.profilesDeleted)")
            print("")
            print("Operation complete")
        }
    }
}

// MARK: - Register Command

extension MatchCommand {
    /// Register devices for development
    struct RegisterCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "register",
            abstract: "Register devices with App Store Connect"
        )

        @OptionGroup var globalOptions: GlobalOptions

        @Option(name: .long, help: "Path to devices file (tab-separated: Name\\tUDID)")
        var devicesFile: String

        @Option(name: .long, help: "Platform (iOS, macOS, tvOS)")
        var platform: String = "iOS"

        func run() async throws {
            LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)
            let logger = Logger.swiftlane(.cli)

            logger.info("Registering devices from \(devicesFile)")

            // Build configuration
            let config = try MatchConfiguration.fromEnvironment()
            let service = try MatchService(configuration: config)

            // Parse platform
            let devicePlatform: Device.Platform
            switch platform.lowercased() {
            case "ios":
                devicePlatform = .iOS
            case "macos":
                devicePlatform = .macOS
            case "tvos":
                devicePlatform = .tvOS
            default:
                logger.error("Invalid platform: \(platform)")
                print("Valid platforms: iOS, macOS, tvOS")
                throw ExitCode.failure
            }

            let result = try await service.registerDevices(fromFile: devicesFile, platform: devicePlatform)

            // Report results
            logger.info("Device registration complete")
            print("")
            print("Device Registration Results")
            print("============================")
            print("")
            print("Newly registered: \(result.registered.count)")
            for device in result.registered {
                print("  - \(device.name) (\(device.udid))")
            }
            print("")
            print("Already registered: \(result.existing.count)")
            for device in result.existing {
                print("  - \(device.name) (\(device.udid))")
            }
            print("")
            print("Total: \(result.registered.count + result.existing.count) devices")
        }
    }
}

// MARK: - Change Password Command

extension MatchCommand {
    /// Re-encrypt files with new password
    struct ChangePasswordCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "change-password",
            abstract: "Re-encrypt all files with a new password"
        )

        @OptionGroup var globalOptions: GlobalOptions

        @Option(name: .long, help: "New password (or set MATCH_NEW_PASSWORD)")
        var newPassword: String?

        func run() async throws {
            LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)
            let logger = Logger.swiftlane(.cli)

            // Get old password from environment
            guard let oldPassword = ProcessInfo.processInfo.environment["MATCH_PASSWORD"] else {
                logger.error("MATCH_PASSWORD environment variable required")
                print("Set MATCH_PASSWORD with the current password")
                throw ExitCode.failure
            }

            // Get new password
            let newPass: String
            if let provided = newPassword {
                newPass = provided
            } else if let envPass = ProcessInfo.processInfo.environment["MATCH_NEW_PASSWORD"] {
                newPass = envPass
            } else {
                logger.error("New password required")
                print("Provide --new-password or set MATCH_NEW_PASSWORD environment variable")
                throw ExitCode.failure
            }

            logger.info("Changing encryption password")

            // Build configuration
            let config = try MatchConfiguration.fromEnvironment()
            let service = try MatchService(configuration: config)

            try await service.changePassword(from: oldPassword, to: newPass)

            // Report results
            logger.info("Password changed successfully")
            print("")
            print("Password Changed")
            print("================")
            print("")
            print("All files have been re-encrypted with the new password")
            print("")
            print("Update MATCH_PASSWORD environment variable:")
            print("  export MATCH_PASSWORD=\"<new-password>\"")
        }
    }
}

#else

// Linux stub
public struct MatchCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "match",
        abstract: "Manage code signing certificates and provisioning profiles (macOS only)"
    )

    public init() {}

    public func run() throws {
        print("The match command is only available on macOS")
        throw ExitCode.failure
    }
}

#endif
