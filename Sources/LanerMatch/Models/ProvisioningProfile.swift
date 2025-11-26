import Foundation

/// Represents a provisioning profile
public struct ProvisioningProfile: Sendable, Codable, Equatable {
    /// Unique identifier from App Store Connect
    public let id: String

    /// Profile UUID (used for file naming)
    public let uuid: String

    /// Profile display name
    public let name: String

    /// Bundle identifier this profile is for
    public let bundleId: String

    /// Profile type
    public let type: CertificateType

    /// Team ID
    public let teamId: String

    /// Team name
    public let teamName: String

    /// Expiration date
    public let expirationDate: Date

    /// Certificate IDs included in this profile
    public let certificateIds: [String]

    /// Device UDIDs included (for development/adhoc)
    public let deviceIds: [String]

    /// Raw profile content (encoded plist)
    public let content: Data?

    public init(
        id: String,
        uuid: String,
        name: String,
        bundleId: String,
        type: CertificateType,
        teamId: String,
        teamName: String,
        expirationDate: Date,
        certificateIds: [String] = [],
        deviceIds: [String] = [],
        content: Data? = nil
    ) {
        self.id = id
        self.uuid = uuid
        self.name = name
        self.bundleId = bundleId
        self.type = type
        self.teamId = teamId
        self.teamName = teamName
        self.expirationDate = expirationDate
        self.certificateIds = certificateIds
        self.deviceIds = deviceIds
        self.content = content
    }

    /// Whether the profile is expired
    public var isExpired: Bool {
        expirationDate < Date()
    }

    /// Installation path for this profile
    public var installPath: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/MobileDevice/Provisioning Profiles")
            .appendingPathComponent("\(uuid).mobileprovision")
    }
}
