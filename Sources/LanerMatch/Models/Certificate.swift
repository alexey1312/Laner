import Foundation

/// Represents a code signing certificate
public struct Certificate: Sendable, Codable, Equatable {
    /// Unique identifier from App Store Connect
    public let id: String

    /// Certificate serial number
    public let serialNumber: String

    /// Certificate display name
    public let name: String

    /// Certificate type (development/distribution)
    public let type: CertificateType

    /// Team ID this certificate belongs to
    public let teamId: String

    /// Expiration date
    public let expirationDate: Date

    /// The raw certificate content (DER encoded)
    public let content: Data?

    public init(
        id: String,
        serialNumber: String,
        name: String,
        type: CertificateType,
        teamId: String,
        expirationDate: Date,
        content: Data? = nil
    ) {
        self.id = id
        self.serialNumber = serialNumber
        self.name = name
        self.type = type
        self.teamId = teamId
        self.expirationDate = expirationDate
        self.content = content
    }

    /// Whether the certificate is expired
    public var isExpired: Bool {
        expirationDate < Date()
    }

    /// Days until expiration (negative if expired)
    public var daysUntilExpiration: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
    }
}
