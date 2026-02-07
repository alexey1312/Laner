import Foundation
import LanerMatch

// MARK: - MatchOptions

/// Options for the match action.
public struct MatchOptions: Sendable {
    /// The type of certificate to sync.
    public let type: CertificateType

    /// Whether to run in readonly mode (don't create new certificates).
    public let readonly: Bool

    /// App identifier(s) to sync profiles for.
    /// If nil or empty, syncs all profiles of the specified type.
    public let appIdentifier: String?

    /// Team ID for code signing.
    public let teamId: String?

    /// Git repository URL for certificate storage.
    public let gitUrl: String?

    /// Force regenerate profiles when new devices are added.
    public let forceForNewDevices: Bool

    /// Git branch to use (defaults to "master").
    public let branch: String

    /// Encryption password for certificates.
    /// If nil, will be read from MATCH_PASSWORD environment variable.
    public let password: String?

    /// Creates match options.
    /// - Parameters:
    ///   - type: The certificate type to sync.
    ///   - readonly: Whether to run in readonly mode. Defaults to false.
    ///   - appIdentifier: App identifier to sync profiles for. Defaults to nil (all apps).
    ///   - teamId: Team ID for code signing. If nil, reads from environment.
    ///   - gitUrl: Git repository URL. If nil, reads from MATCH_GIT_URL environment.
    ///   - forceForNewDevices: Force profile regeneration. Defaults to false.
    ///   - branch: Git branch to use. Defaults to "master".
    ///   - password: Encryption password. If nil, reads from MATCH_PASSWORD environment.
    public init(
        type: CertificateType,
        readonly: Bool = false,
        appIdentifier: String? = nil,
        teamId: String? = nil,
        gitUrl: String? = nil,
        forceForNewDevices: Bool = false,
        branch: String = "master",
        password: String? = nil
    ) {
        self.type = type
        self.readonly = readonly
        self.appIdentifier = appIdentifier
        self.teamId = teamId
        self.gitUrl = gitUrl
        self.forceForNewDevices = forceForNewDevices
        self.branch = branch
        self.password = password
    }
}

// MARK: - MatchAction

/// Action that syncs code signing certificates and provisioning profiles.
///
/// This action uses Match to download and install certificates and profiles
/// from a Git repository, similar to Fastlane Match.
///
/// ## Example
/// ```swift
/// lane("sign") {
///     match(
///         type: .appstore,
///         appIdentifier: "com.example.app",
///         readonly: true
///     )
/// }
/// ```
public struct MatchAction: Action {
    public typealias Options = MatchOptions
    public typealias Result = SyncResult

    public static let name = "match"
    public static let description = "Sync code signing certificates and provisioning profiles"

    public let options: MatchOptions

    /// Creates a match action.
    /// - Parameter options: The match options.
    public init(options: MatchOptions) {
        self.options = options
    }

    @MainActor
    public func execute(context: ExecutionContext) async throws -> SyncResult {
        context.logger.info("[\(Self.name)] Syncing \(options.type.rawValue) certificates")

        // Build configuration
        let password = try resolvePassword(from: context)
        let gitUrl = try resolveGitUrl(from: context)
        let teamId = try resolveTeamId(from: context)

        context.logger.info("[\(Self.name)]   Git URL: \(gitUrl)")
        context.logger.info("[\(Self.name)]   Branch: \(options.branch)")
        context.logger.info("[\(Self.name)]   Team ID: \(teamId)")
        context.logger.info("[\(Self.name)]   Readonly: \(options.readonly)")

        if let appId = options.appIdentifier {
            context.logger.info("[\(Self.name)]   App Identifier: \(appId)")
        }

        if options.forceForNewDevices {
            context.logger.info("[\(Self.name)]   Force for new devices: enabled")
        }

        // Create Match configuration
        let config = MatchConfiguration(
            gitUrl: gitUrl,
            branch: options.branch,
            teamId: teamId,
            apiKeyId: context.environment["APP_STORE_CONNECT_API_KEY_ID"],
            apiIssuerId: context.environment["APP_STORE_CONNECT_API_ISSUER_ID"],
            apiKeyPath: context.environment["APP_STORE_CONNECT_API_KEY_PATH"],
            password: password,
            readonly: options.readonly,
            forceForNewDevices: options.forceForNewDevices
        )

        // Create and execute Match service
        let service = try MatchService(configuration: config)

        let appIdentifiers = options.appIdentifier.map { [$0] } ?? []
        let result = try await service.sync(type: options.type, appIdentifiers: appIdentifiers)

        let certs = result.certificates.count
        let profiles = result.profiles.count
        context.logger.info("[\(Self.name)] Sync complete: \(certs) certificates, \(profiles) profiles")

        return result
    }

    // MARK: - Helpers

    private func resolvePassword(from context: ExecutionContext) throws -> String {
        if let password = options.password, !password.isEmpty {
            return password
        }

        guard let envPassword = context.environment["MATCH_PASSWORD"] else {
            throw MatchActionError.missingPassword
        }

        return envPassword
    }

    private func resolveGitUrl(from context: ExecutionContext) throws -> String {
        if let gitUrl = options.gitUrl {
            return gitUrl
        }

        guard let envGitUrl = context.environment["MATCH_GIT_URL"] else {
            throw MatchActionError.missingGitUrl
        }

        return envGitUrl
    }

    private func resolveTeamId(from context: ExecutionContext) throws -> String {
        if let teamId = options.teamId {
            return teamId
        }

        guard let envTeamId = context.environment["MATCH_TEAM_ID"] else {
            throw MatchActionError.missingTeamId
        }

        return envTeamId
    }
}

// MARK: - MatchActionError

/// Errors that can occur during match action execution.
public enum MatchActionError: Error, LocalizedError {
    /// Match password is not provided via options or MATCH_PASSWORD environment variable.
    case missingPassword

    /// Git URL is not provided via options or MATCH_GIT_URL environment variable.
    case missingGitUrl

    /// Team ID is not provided via options or MATCH_TEAM_ID environment variable.
    case missingTeamId

    public var errorDescription: String? {
        switch self {
        case .missingPassword:
            "Match password must be provided via options or MATCH_PASSWORD environment variable"
        case .missingGitUrl:
            "Git URL must be provided via options or MATCH_GIT_URL environment variable"
        case .missingTeamId:
            "Team ID must be provided via options or MATCH_TEAM_ID environment variable"
        }
    }
}
