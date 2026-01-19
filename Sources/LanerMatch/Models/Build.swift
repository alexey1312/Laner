import Foundation

/// Represents a build uploaded to App Store Connect.
public struct Build: Codable, Sendable, Equatable {
    /// The unique identifier for the build.
    public let id: String

    /// The build version string (CFBundleVersion).
    public let version: String

    /// The app version string (CFBundleShortVersionString).
    public let appVersion: String?

    /// The current processing state of the build.
    public let processingState: ProcessingState

    /// The date when the build was uploaded.
    public let uploadedDate: Date?

    /// The minimum OS version required by the build.
    public let minOsVersion: String?

    /// Whether the build uses non-exempt encryption.
    public let usesNonExemptEncryption: Bool?

    /// Creates a new Build instance.
    public init(
        id: String,
        version: String,
        appVersion: String? = nil,
        processingState: ProcessingState,
        uploadedDate: Date? = nil,
        minOsVersion: String? = nil,
        usesNonExemptEncryption: Bool? = nil
    ) {
        self.id = id
        self.version = version
        self.appVersion = appVersion
        self.processingState = processingState
        self.uploadedDate = uploadedDate
        self.minOsVersion = minOsVersion
        self.usesNonExemptEncryption = usesNonExemptEncryption
    }
}

// MARK: - ProcessingState

public extension Build {
    /// The processing state of a build.
    enum ProcessingState: String, Codable, Sendable, Equatable {
        /// The build is being processed by Apple.
        case processing = "PROCESSING"

        /// The build failed processing.
        case failed = "FAILED"

        /// The build has been processed and is invalid.
        case invalid = "INVALID"

        /// The build has been processed and is valid.
        case valid = "VALID"

        /// Unknown state (for forward compatibility).
        case unknown

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = ProcessingState(rawValue: rawValue) ?? .unknown
        }
    }
}
