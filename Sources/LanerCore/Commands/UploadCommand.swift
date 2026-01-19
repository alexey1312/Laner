import ArgumentParser
import Foundation
import LanerKit
import LanerMatch
import Logging

/// Parent command for upload operations.
public struct UploadCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "upload",
        abstract: "Upload builds to distribution services",
        subcommands: [
            TestFlightUploadCommand.self,
        ]
    )

    public init() {}
}

// MARK: - TestFlight Upload Command

#if os(macOS)

    /// Uploads a build to TestFlight.
    public struct TestFlightUploadCommand: AsyncParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "testflight",
            abstract: "Upload a build to TestFlight"
        )

        @OptionGroup var globalOptions: GlobalOptions

        @Option(name: .long, help: "Path to the IPA file to upload")
        var ipa: String

        @Option(name: .long, help: "App Store Connect app ID (or set APP_STORE_APP_ID)")
        var appId: String?

        @Option(name: .long, help: "Release notes (what's new) for testers")
        var changelog: String?

        @Option(name: .long, help: "Beta groups to distribute to (comma-separated)")
        var groups: String?

        @Flag(name: .long, help: "Don't wait for Apple to finish processing the build")
        var skipWaiting: Bool = false

        public init() {}

        public func run() async throws {
            LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)
            let logger = Logger.laner(.cli)

            // Validate IPA exists
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: ipa, isDirectory: &isDirectory),
                  !isDirectory.boolValue
            else {
                logger.error("IPA file not found: \(ipa)")
                throw ExitCode.failure
            }

            // Resolve app ID
            let resolvedAppId: String
            if let appId {
                resolvedAppId = appId
            } else if let envAppId = ProcessInfo.processInfo.environment["APP_STORE_APP_ID"] {
                resolvedAppId = envAppId
            } else {
                logger.error("App ID is required. Provide --app-id or set APP_STORE_APP_ID environment variable.")
                throw ExitCode.failure
            }

            // Resolve API credentials
            guard let apiKeyId = ProcessInfo.processInfo.environment["APP_STORE_CONNECT_API_KEY_ID"] else {
                logger.error("Missing APP_STORE_CONNECT_API_KEY_ID environment variable")
                throw ExitCode.failure
            }

            guard let apiIssuerId = ProcessInfo.processInfo.environment["APP_STORE_CONNECT_API_ISSUER_ID"] else {
                logger.error("Missing APP_STORE_CONNECT_API_ISSUER_ID environment variable")
                throw ExitCode.failure
            }

            guard let apiKeyPath = ProcessInfo.processInfo.environment["APP_STORE_CONNECT_API_KEY_PATH"] else {
                logger.error("Missing APP_STORE_CONNECT_API_KEY_PATH environment variable")
                throw ExitCode.failure
            }

            // Parse groups
            let groupList: [String]? = if let groups {
                groups.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            } else {
                nil
            }

            // Print configuration
            print("")
            print("TestFlight Upload")
            print("=================")
            print("")
            print("IPA: \(ipa)")
            print("App ID: \(resolvedAppId)")
            if let changelog {
                print("Changelog: \(changelog.prefix(80))...")
            }
            if let groupList, !groupList.isEmpty {
                print("Groups: \(groupList.joined(separator: ", "))")
            }
            print("Skip waiting: \(skipWaiting)")
            print("")

            logger.info("Starting TestFlight upload")

            // Create API client
            let api: AppStoreConnectAPI
            do {
                api = try AppStoreConnectAPI(
                    keyId: apiKeyId,
                    issuerId: apiIssuerId,
                    privateKeyPath: apiKeyPath
                )
            } catch {
                logger.error("Failed to initialize API client: \(error)")
                throw ExitCode.failure
            }

            defer {
                Task {
                    try? await api.shutdown()
                }
            }

            // Create TestFlight service
            let service = TestFlightService(api: api)

            do {
                // Upload and distribute
                let build = try await service.uploadAndDistribute(
                    ipaPath: ipa,
                    appId: resolvedAppId,
                    groups: groupList,
                    whatsNew: changelog,
                    skipWaitingForProcessing: skipWaiting,
                    progress: { progress in
                        let percent = String(format: "%.1f", progress.percentage)
                        let chunks = "\(progress.currentChunk)/\(progress.totalChunks)"
                        print("Uploading... \(percent)% (\(chunks) chunks)")
                    }
                )

                // Print success
                print("")
                print("Upload Successful")
                print("=================")
                print("")
                print("Build version: \(build.version)")
                if let appVersion = build.appVersion {
                    print("App version: \(appVersion)")
                }
                print("Processing state: \(build.processingState.rawValue)")
                print("Build ID: \(build.id)")

                if !skipWaiting, build.processingState == .valid {
                    print("")
                    print("Build is ready for testing!")
                    if let groupList, !groupList.isEmpty {
                        print("Distributed to: \(groupList.joined(separator: ", "))")
                    }
                } else if skipWaiting {
                    print("")
                    print("Build uploaded. Check App Store Connect for processing status.")
                }

                logger.info("TestFlight upload completed successfully")

            } catch let error as TestFlightError {
                logger.error("TestFlight error: \(error.localizedDescription)")
                print("")
                print("Error: \(error.localizedDescription)")
                throw ExitCode.failure
            } catch {
                logger.error("Unexpected error: \(error)")
                print("")
                print("Error: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }

#else

    // Linux stub
    public struct TestFlightUploadCommand: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "testflight",
            abstract: "Upload a build to TestFlight (macOS only)"
        )

        public init() {}

        public func run() throws {
            print("TestFlight upload is only available on macOS")
            throw ExitCode.failure
        }
    }

#endif
