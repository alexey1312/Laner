import Foundation

/// The type of build artifact.
public enum ArtifactType: String, Sendable, CaseIterable {
    /// An iOS app archive (.ipa).
    case ipa

    /// A macOS app bundle (.app).
    case app

    /// An Xcode archive (.xcarchive).
    case xcarchive

    /// A dSYM debug symbols file.
    case dsym

    /// An App Store Connect API key.
    case apiKey

    /// A provisioning profile.
    case provisioningProfile

    /// A certificate.
    case certificate

    /// Test results.
    case testResults

    /// Code coverage report.
    case coverage

    /// A generic file artifact.
    case file
}

/// Represents a build artifact produced during lane execution.
public struct Artifact: Sendable, Equatable {
    /// The type of artifact.
    public let type: ArtifactType

    /// The path to the artifact.
    public let path: URL

    /// Optional name for the artifact (defaults to filename).
    public let name: String

    /// Additional metadata about the artifact.
    public let metadata: [String: String]

    /// The timestamp when the artifact was created.
    public let createdAt: Date

    /// Creates a new artifact.
    /// - Parameters:
    ///   - type: The type of artifact.
    ///   - path: The path to the artifact file.
    ///   - name: Optional name (defaults to filename).
    ///   - metadata: Additional metadata.
    public init(
        type: ArtifactType,
        path: URL,
        name: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.type = type
        self.path = path
        self.name = name ?? path.lastPathComponent
        self.metadata = metadata
        self.createdAt = Date()
    }

    /// Whether the artifact file exists (file or directory).
    public var exists: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path.path(percentEncoded: false), isDirectory: &isDirectory)
    }

    /// The file size in bytes, if available.
    public var fileSize: Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path.path(percentEncoded: false)),
              let size = attrs[.size] as? Int64
        else {
            return nil
        }
        return size
    }
}

/// A storage container for artifacts produced during lane execution.
public actor ArtifactStore {
    /// The stored artifacts.
    private var artifacts: [Artifact] = []

    /// Creates a new empty artifact store.
    public init() {}

    /// Adds an artifact to the store.
    /// - Parameter artifact: The artifact to add.
    public func add(_ artifact: Artifact) {
        artifacts.append(artifact)
    }

    /// Removes all artifacts from the store.
    public func clear() {
        artifacts.removeAll()
    }

    /// Returns all stored artifacts.
    public func all() -> [Artifact] {
        artifacts
    }

    /// Returns all artifacts of a specific type.
    /// - Parameter type: The artifact type to filter by.
    /// - Returns: Artifacts matching the type.
    public func artifacts(ofType type: ArtifactType) -> [Artifact] {
        artifacts.filter { $0.type == type }
    }

    /// Returns the first artifact of a specific type.
    /// - Parameter type: The artifact type to find.
    /// - Returns: The first matching artifact, or nil.
    public func artifact(ofType type: ArtifactType) -> Artifact? {
        artifacts.first { $0.type == type }
    }

    /// Returns the most recent artifact of a specific type.
    /// - Parameter type: The artifact type to find.
    /// - Returns: The most recently added matching artifact, or nil.
    public func latestArtifact(ofType type: ArtifactType) -> Artifact? {
        artifacts.last { $0.type == type }
    }

    /// Returns artifacts matching a name pattern.
    /// - Parameter pattern: The pattern to match (supports wildcards).
    /// - Returns: Matching artifacts.
    public func artifacts(matching pattern: String) -> [Artifact] {
        let regex = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")

        guard let regex = try? NSRegularExpression(pattern: "^\(regex)$", options: []) else {
            return artifacts.filter { $0.name == pattern }
        }

        return artifacts.filter { artifact in
            let range = NSRange(artifact.name.startIndex..., in: artifact.name)
            return regex.firstMatch(in: artifact.name, options: [], range: range) != nil
        }
    }
}
