import Foundation

/// Represents a TestFlight beta group.
public struct BetaGroup: Codable, Sendable, Equatable {
    /// The unique identifier for the beta group.
    public let id: String

    /// The name of the beta group.
    public let name: String

    /// Whether this is an internal testing group.
    public let isInternalGroup: Bool

    /// The public link status.
    public let publicLinkEnabled: Bool?

    /// The public link for joining (if enabled).
    public let publicLink: String?

    /// Creates a new BetaGroup instance.
    public init(
        id: String,
        name: String,
        isInternalGroup: Bool,
        publicLinkEnabled: Bool? = nil,
        publicLink: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isInternalGroup = isInternalGroup
        self.publicLinkEnabled = publicLinkEnabled
        self.publicLink = publicLink
    }
}
