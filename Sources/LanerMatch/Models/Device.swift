import Foundation

/// Represents a registered device
public struct Device: Sendable, Codable, Equatable {
    /// Unique identifier from App Store Connect
    public let id: String

    /// Device UDID
    public let udid: String

    /// Device name
    public let name: String

    /// Device platform
    public let platform: Platform

    /// Device class (iPhone, iPad, etc.)
    public let deviceClass: DeviceClass

    /// Device status
    public let status: Status

    /// Date device was added
    public let addedDate: Date?

    public init(
        id: String,
        udid: String,
        name: String,
        platform: Platform,
        deviceClass: DeviceClass,
        status: Status,
        addedDate: Date? = nil
    ) {
        self.id = id
        self.udid = udid
        self.name = name
        self.platform = platform
        self.deviceClass = deviceClass
        self.status = status
        self.addedDate = addedDate
    }

    /// Device platform
    public enum Platform: String, Sendable, Codable, CaseIterable {
        case iOS = "IOS"
        case macOS = "MAC_OS"
        case tvOS = "TVOS"
        case watchOS = "WATCHOS"
        case visionOS = "VISIONOS"
    }

    /// Device class
    public enum DeviceClass: String, Sendable, Codable {
        case iPhone = "IPHONE"
        case iPad = "IPAD"
        case mac = "MAC"
        case appleTV = "APPLE_TV"
        case appleWatch = "APPLE_WATCH"
        case appleVision = "APPLE_VISION"
        case unknown = "UNKNOWN"
    }

    /// Device status
    public enum Status: String, Sendable, Codable {
        case enabled = "ENABLED"
        case disabled = "DISABLED"
    }
}
