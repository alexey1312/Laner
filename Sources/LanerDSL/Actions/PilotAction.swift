import Foundation
import LanerMatch

// MARK: - PilotOptions

/// Options for the pilot (TestFlight upload) action.
public struct PilotOptions: Sendable {
    /// Path to the IPA file to upload.
    /// If nil, will look for IPA in artifacts from previous gym/archive action.
    public let ipa: String?

    /// The App Store Connect app ID.
    /// If nil, will be read from APP_STORE_APP_ID environment variable.
    public let appId: String?

    /// Release notes (what's new) for TestFlight testers.
    public let changelog: String?

    /// Names of beta groups to distribute to.
    public let groups: [String]?

    /// Skip waiting for Apple to process the build.
    public let skipWaitingForProcessing: Bool

    /// Creates pilot options.
    /// - Parameters:
    ///   - ipa: Path to the IPA file.
    ///   - appId: App Store Connect app ID.
    ///   - changelog: Release notes for testers.
    ///   - groups: Beta groups to distribute to.
    ///   - skipWaitingForProcessing: Skip waiting for processing.
    public init(
        ipa: String? = nil,
        appId: String? = nil,
        changelog: String? = nil,
        groups: [String]? = nil,
        skipWaitingForProcessing: Bool = true
    ) {
        self.ipa = ipa
        self.appId = appId
        self.changelog = changelog
        self.groups = groups
        self.skipWaitingForProcessing = skipWaitingForProcessing
    }
}

// MARK: - PilotResult

/// Result of a pilot (TestFlight upload) action.
public struct PilotResult: Sendable {
    /// The uploaded build information.
    public let build: Build

    /// The app ID used for upload.
    public let appId: String

    /// The IPA path that was uploaded.
    public let ipaPath: String

    /// Creates a pilot result.
    public init(build: Build, appId: String, ipaPath: String) {
        self.build = build
        self.appId = appId
        self.ipaPath = ipaPath
    }
}

// MARK: - PilotAction

/// Action that uploads a build to TestFlight.
///
/// This action uploads an IPA to App Store Connect and optionally
/// distributes it to beta testers.
///
/// ## Example
/// ```swift
/// lane("beta") {
///     match(type: .appstore, readonly: true)
///     gym(scheme: "MyApp", exportMethod: .appStore)
///     pilot(
///         appId: "123456789",
///         changelog: "Bug fixes and improvements",
///         groups: ["Internal", "External Testers"]
///     )
/// }
/// ```
public struct PilotAction: Action {
    public typealias Options = PilotOptions
    public typealias Result = PilotResult

    public static let name = "pilot"
    public static let description = "Upload a build to TestFlight"

    public let options: PilotOptions

    /// Creates a pilot action.
    /// - Parameter options: The pilot options.
    public init(options: PilotOptions) {
        self.options = options
    }

    @MainActor
    public func execute(context: ExecutionContext) async throws -> PilotResult {
        #if !os(macOS)
            throw TestFlightError.platformNotSupported
        #else
            context.logger.info("[\(Self.name)] Starting TestFlight upload")

            // Resolve IPA path
            let ipaPath = try resolveIPAPath(from: context)
            context.logger.info("[\(Self.name)]   IPA: \(ipaPath)")

            // Resolve app ID
            let appId = try resolveAppId(from: context)
            context.logger.info("[\(Self.name)]   App ID: \(appId)")

            // Resolve API credentials
            let apiKeyId = try resolveCredential(
                from: context,
                key: "APP_STORE_CONNECT_API_KEY_ID"
            )
            let apiIssuerId = try resolveCredential(
                from: context,
                key: "APP_STORE_CONNECT_API_ISSUER_ID"
            )
            let apiKeyPath = try resolveCredential(
                from: context,
                key: "APP_STORE_CONNECT_API_KEY_PATH"
            )

            // Log options
            if let changelog = options.changelog {
                context.logger.info("[\(Self.name)]   Changelog: \(changelog.prefix(50))...")
            }

            if let groups = options.groups, !groups.isEmpty {
                context.logger.info("[\(Self.name)]   Groups: \(groups.joined(separator: ", "))")
            }

            context.logger.info("[\(Self.name)]   Skip waiting: \(options.skipWaitingForProcessing)")

            // Create API client
            let api = try AppStoreConnectAPI(
                keyId: apiKeyId,
                issuerId: apiIssuerId,
                privateKeyPath: apiKeyPath
            )

            defer {
                Task {
                    try? await api.shutdown()
                }
            }

            // Create TestFlight service
            let service = TestFlightService(api: api)

            // Upload and distribute
            let build = try await service.uploadAndDistribute(
                ipaPath: ipaPath,
                appId: appId,
                groups: options.groups,
                whatsNew: options.changelog,
                skipWaitingForProcessing: options.skipWaitingForProcessing,
                progress: { progress in
                    let percent = String(format: "%.1f", progress.percentage)
                    let chunks = "\(progress.currentChunk)/\(progress.totalChunks)"
                    print("[pilot]   Upload: \(percent)% (\(chunks) chunks)")
                }
            )

            context.logger.info("[\(Self.name)] Upload completed successfully")
            context.logger.info("[\(Self.name)]   Build version: \(build.version)")
            context.logger.info("[\(Self.name)]   Processing state: \(build.processingState.rawValue)")

            return PilotResult(
                build: build,
                appId: appId,
                ipaPath: ipaPath
            )
        #endif
    }

    // MARK: - Helpers

    private func resolveIPAPath(from context: ExecutionContext) throws -> String {
        // Use explicit path if provided
        if let ipa = options.ipa {
            // Validate file exists
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: ipa, isDirectory: &isDirectory),
                  !isDirectory.boolValue
            else {
                throw TestFlightError.ipaNotFound(ipa)
            }
            return ipa
        }

        // Look for IPA in artifacts
        // TODO: Implement artifact discovery from previous gym/archive action
        throw PilotActionError.missingIPA
    }

    private func resolveAppId(from context: ExecutionContext) throws -> String {
        if let appId = options.appId {
            return appId
        }

        guard let envAppId = context.environment["APP_STORE_APP_ID"] else {
            throw TestFlightError.missingAppId
        }

        return envAppId
    }

    private func resolveCredential(from context: ExecutionContext, key: String) throws -> String {
        guard let value = context.environment[key] else {
            throw TestFlightError.missingCredentials(key)
        }
        return value
    }
}

// MARK: - PilotActionError

/// Errors specific to the pilot action.
public enum PilotActionError: Error, LocalizedError {
    /// No IPA path provided and no IPA found in artifacts.
    case missingIPA

    public var errorDescription: String? {
        switch self {
        case .missingIPA:
            "No IPA path provided. Use --ipa option or run gym/archive action first."
        }
    }
}
