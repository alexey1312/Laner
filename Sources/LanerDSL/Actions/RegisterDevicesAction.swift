import Foundation
import LanerMatch

// MARK: - RegisterDevicesOptions

/// Options for the registerDevices action.
public struct RegisterDevicesOptions: Sendable {
    /// Path to a file containing device names and UDIDs.
    /// Format: "Device Name\tUDID" per line.
    public let file: String?

    /// Dictionary of device name to UDID mappings.
    public let devices: [String: String]?

    /// Platform for the devices.
    public let platform: Device.Platform

    /// Team ID for device registration.
    public let teamId: String?

    /// App Store Connect API key ID.
    public let apiKeyId: String?

    /// App Store Connect API issuer ID.
    public let apiIssuerId: String?

    /// Path to App Store Connect API private key (.p8).
    public let apiKeyPath: String?

    /// Creates register devices options with a file.
    /// - Parameters:
    ///   - file: Path to the devices file.
    ///   - platform: Device platform. Defaults to iOS.
    ///   - teamId: Team ID. If nil, reads from environment.
    ///   - apiKeyId: API key ID. If nil, reads from environment.
    ///   - apiIssuerId: API issuer ID. If nil, reads from environment.
    ///   - apiKeyPath: API key path. If nil, reads from environment.
    public init(
        file: String,
        platform: Device.Platform = .iOS,
        teamId: String? = nil,
        apiKeyId: String? = nil,
        apiIssuerId: String? = nil,
        apiKeyPath: String? = nil
    ) {
        self.file = file
        self.devices = nil
        self.platform = platform
        self.teamId = teamId
        self.apiKeyId = apiKeyId
        self.apiIssuerId = apiIssuerId
        self.apiKeyPath = apiKeyPath
    }

    /// Creates register devices options with a device dictionary.
    /// - Parameters:
    ///   - devices: Dictionary mapping device names to UDIDs.
    ///   - platform: Device platform. Defaults to iOS.
    ///   - teamId: Team ID. If nil, reads from environment.
    ///   - apiKeyId: API key ID. If nil, reads from environment.
    ///   - apiIssuerId: API issuer ID. If nil, reads from environment.
    ///   - apiKeyPath: API key path. If nil, reads from environment.
    public init(
        devices: [String: String],
        platform: Device.Platform = .iOS,
        teamId: String? = nil,
        apiKeyId: String? = nil,
        apiIssuerId: String? = nil,
        apiKeyPath: String? = nil
    ) {
        self.file = nil
        self.devices = devices
        self.platform = platform
        self.teamId = teamId
        self.apiKeyId = apiKeyId
        self.apiIssuerId = apiIssuerId
        self.apiKeyPath = apiKeyPath
    }
}

// MARK: - RegisterDevicesAction

/// Action that registers devices with Apple Developer Portal.
///
/// This action registers devices from a file or dictionary with the Apple
/// Developer Portal, making them available for development and ad-hoc builds.
///
/// ## Example
/// ```swift
/// lane("register") {
///     registerDevices(file: "devices.txt")
///     match(type: .adhoc, forceForNewDevices: true)
/// }
/// ```
public struct RegisterDevicesAction: Action {
    public typealias Options = RegisterDevicesOptions
    public typealias Result = RegisterDevicesResult

    public static let name = "register_devices"
    public static let description = "Register devices with Apple Developer Portal"

    public let options: RegisterDevicesOptions

    /// Creates a register devices action.
    /// - Parameter options: The register devices options.
    public init(options: RegisterDevicesOptions) {
        self.options = options
    }

    @MainActor
    public func execute(context: ExecutionContext) async throws -> RegisterDevicesResult {
        context.logger.info("[\(Self.name)] Registering devices")
        context.logger.info("[\(Self.name)]   Platform: \(options.platform.rawValue)")

        // Resolve API credentials
        let teamId = try resolveTeamId(from: context)
        let apiKeyId = try resolveApiKeyId(from: context)
        let apiIssuerId = try resolveApiIssuerId(from: context)
        let apiKeyPath = try resolveApiKeyPath(from: context)

        context.logger.info("[\(Self.name)]   Team ID: \(teamId)")

        // Create Match configuration (we need it for the service)
        let config = MatchConfiguration(
            gitUrl: "dummy", // Not used for device registration
            branch: "master",
            teamId: teamId,
            apiKeyId: apiKeyId,
            apiIssuerId: apiIssuerId,
            apiKeyPath: apiKeyPath,
            password: "dummy", // Not used for device registration
            readonly: false,
            forceForNewDevices: false
        )

        let service = try MatchService(configuration: config)

        let result: RegisterDevicesResult

        if let file = options.file {
            context.logger.info("[\(Self.name)]   Source: file at \(file)")
            result = try await service.registerDevices(fromFile: file)
        } else if let devices = options.devices {
            context.logger.info("[\(Self.name)]   Source: \(devices.count) devices from dictionary")
            let deviceArray = devices.map { (name: $0.key, udid: $0.value) }
            result = try await service.registerDevices(deviceArray, platform: options.platform)
        } else {
            throw RegisterDevicesActionError.noDeviceSource
        }

        context.logger.info("[\(Self.name)] Registration complete: \(result.registered.count) new, \(result.existing.count) existing")

        return result
    }

    // MARK: - Helpers

    private func resolveTeamId(from context: ExecutionContext) throws -> String {
        if let teamId = options.teamId {
            return teamId
        }

        guard let envTeamId = context.environment["MATCH_TEAM_ID"] else {
            throw RegisterDevicesActionError.missingTeamId
        }

        return envTeamId
    }

    private func resolveApiKeyId(from context: ExecutionContext) throws -> String {
        if let apiKeyId = options.apiKeyId {
            return apiKeyId
        }

        guard let envApiKeyId = context.environment["APP_STORE_CONNECT_API_KEY_ID"] else {
            throw RegisterDevicesActionError.missingApiKeyId
        }

        return envApiKeyId
    }

    private func resolveApiIssuerId(from context: ExecutionContext) throws -> String {
        if let apiIssuerId = options.apiIssuerId {
            return apiIssuerId
        }

        guard let envApiIssuerId = context.environment["APP_STORE_CONNECT_API_ISSUER_ID"] else {
            throw RegisterDevicesActionError.missingApiIssuerId
        }

        return envApiIssuerId
    }

    private func resolveApiKeyPath(from context: ExecutionContext) throws -> String {
        if let apiKeyPath = options.apiKeyPath {
            return apiKeyPath
        }

        guard let envApiKeyPath = context.environment["APP_STORE_CONNECT_API_KEY_PATH"] else {
            throw RegisterDevicesActionError.missingApiKeyPath
        }

        return envApiKeyPath
    }
}

// MARK: - RegisterDevicesActionError

/// Errors that can occur during device registration.
public enum RegisterDevicesActionError: Error, LocalizedError {
    /// No device source (file or devices dictionary) was provided.
    case noDeviceSource

    /// Team ID is not provided via options or environment.
    case missingTeamId

    /// API key ID is not provided via options or environment.
    case missingApiKeyId

    /// API issuer ID is not provided via options or environment.
    case missingApiIssuerId

    /// API key path is not provided via options or environment.
    case missingApiKeyPath

    public var errorDescription: String? {
        switch self {
        case .noDeviceSource:
            return "No device source provided. Must specify either 'file' or 'devices' parameter"
        case .missingTeamId:
            return "Team ID must be provided via options or MATCH_TEAM_ID environment variable"
        case .missingApiKeyId:
            return "API Key ID must be provided via options or APP_STORE_CONNECT_API_KEY_ID environment variable"
        case .missingApiIssuerId:
            return "API Issuer ID must be provided via options or APP_STORE_CONNECT_API_ISSUER_ID environment variable"
        case .missingApiKeyPath:
            return "API Key path must be provided via options or APP_STORE_CONNECT_API_KEY_PATH environment variable"
        }
    }
}

// MARK: - DSL Functions

/// Registers devices from a file with Apple Developer Portal.
///
/// The file should contain one device per line in the format:
/// "Device Name\tUDID" or "UDID\tDevice Name"
///
/// ## Example
/// ```swift
/// lane("register") {
///     registerDevices(file: "devices.txt")
///     match(type: .adhoc, forceForNewDevices: true)
/// }
/// ```
///
/// - Parameters:
///   - file: Path to the devices file.
///   - platform: Device platform. Defaults to iOS.
///   - teamId: Team ID. If nil, reads from MATCH_TEAM_ID environment.
///   - apiKeyId: API key ID. If nil, reads from APP_STORE_CONNECT_API_KEY_ID environment.
///   - apiIssuerId: API issuer ID. If nil, reads from APP_STORE_CONNECT_API_ISSUER_ID environment.
///   - apiKeyPath: API key path. If nil, reads from APP_STORE_CONNECT_API_KEY_PATH environment.
/// - Returns: A type-erased action that can be executed in a lane.
public func registerDevices(
    file: String,
    platform: Device.Platform = .iOS,
    teamId: String? = nil,
    apiKeyId: String? = nil,
    apiIssuerId: String? = nil,
    apiKeyPath: String? = nil
) -> AnyAction {
    AnyAction(
        RegisterDevicesAction(
            options: RegisterDevicesOptions(
                file: file,
                platform: platform,
                teamId: teamId,
                apiKeyId: apiKeyId,
                apiIssuerId: apiIssuerId,
                apiKeyPath: apiKeyPath
            )
        )
    )
}

/// Registers devices from a dictionary with Apple Developer Portal.
///
/// ## Example
/// ```swift
/// lane("register") {
///     registerDevices(devices: [
///         "John's iPhone": "00008030-001234567890401E",
///         "Jane's iPad": "00008101-000123456789012E"
///     ])
///     match(type: .adhoc, forceForNewDevices: true)
/// }
/// ```
///
/// - Parameters:
///   - devices: Dictionary mapping device names to UDIDs.
///   - platform: Device platform. Defaults to iOS.
///   - teamId: Team ID. If nil, reads from MATCH_TEAM_ID environment.
///   - apiKeyId: API key ID. If nil, reads from APP_STORE_CONNECT_API_KEY_ID environment.
///   - apiIssuerId: API issuer ID. If nil, reads from APP_STORE_CONNECT_API_ISSUER_ID environment.
///   - apiKeyPath: API key path. If nil, reads from APP_STORE_CONNECT_API_KEY_PATH environment.
/// - Returns: A type-erased action that can be executed in a lane.
public func registerDevices(
    devices: [String: String],
    platform: Device.Platform = .iOS,
    teamId: String? = nil,
    apiKeyId: String? = nil,
    apiIssuerId: String? = nil,
    apiKeyPath: String? = nil
) -> AnyAction {
    AnyAction(
        RegisterDevicesAction(
            options: RegisterDevicesOptions(
                devices: devices,
                platform: platform,
                teamId: teamId,
                apiKeyId: apiKeyId,
                apiIssuerId: apiIssuerId,
                apiKeyPath: apiKeyPath
            )
        )
    )
}
