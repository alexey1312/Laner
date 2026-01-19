import Foundation

/// Metadata for a lane that can be serialized.
///
/// Since `Lane` contains execution closures that cannot be encoded,
/// `LaneMetadata` provides a serializable representation containing
/// only the lane's name and description.
public struct LaneMetadata: Codable, Sendable, Hashable {
    /// The unique name of the lane.
    public let name: String

    /// A human-readable description of what the lane does.
    public let description: String

    /// Creates lane metadata.
    /// - Parameters:
    ///   - name: The unique name of the lane.
    ///   - description: A description of what the lane does.
    public init(name: String, description: String = "") {
        self.name = name
        self.description = description
    }

    /// Creates metadata from a lane.
    /// - Parameter lane: The lane to extract metadata from.
    public init(from lane: Lane) {
        name = lane.name
        description = lane.description
    }
}

/// The root configuration type for a Laner manifest.
///
/// A Lanerfile defines the lanes available for execution in a CI/CD pipeline.
/// It can be serialized to JSON for inspection and tooling purposes.
///
/// ## Example
/// ```swift
/// let manifest = Lanerfile(lanes: [
///     Lane(name: "build", description: "Builds the app") { context in
///         // Build actions...
///     },
///     Lane(name: "test", description: "Runs tests") { context in
///         // Test actions...
///     }
/// ])
///
/// // Lookup a lane by name
/// if let buildLane = manifest.lane(named: "build") {
///     await runner.run(buildLane)
/// }
/// ```
public struct Lanerfile: Sendable {
    /// The lanes defined in this manifest.
    public let lanes: [Lane]

    /// Creates a Lanerfile with the given lanes.
    /// - Parameter lanes: The lanes to include in the manifest.
    public init(lanes: [Lane]) {
        self.lanes = lanes
    }

    /// Looks up a lane by name.
    /// - Parameter name: The name of the lane to find.
    /// - Returns: The lane with the given name, or nil if not found.
    public func lane(named name: String) -> Lane? {
        lanes.first { $0.name == name }
    }

    /// Returns all lane names defined in this manifest.
    public var laneNames: [String] {
        lanes.map(\.name)
    }

    /// Returns metadata for all lanes in this manifest.
    ///
    /// Use this for serialization or inspection purposes.
    public var metadata: [LaneMetadata] {
        lanes.map { LaneMetadata(from: $0) }
    }
}

// MARK: - Codable Support

extension Lanerfile: Codable {
    enum CodingKeys: String, CodingKey {
        case lanes
    }

    /// Decodes a Lanerfile from metadata only.
    ///
    /// Note: Decoded lanes will have empty execution bodies.
    /// This initializer is primarily for tooling and inspection.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let metadata = try container.decode([LaneMetadata].self, forKey: .lanes)

        // Create lanes with empty bodies for metadata-only representation
        lanes = metadata.map { meta in
            Lane(name: meta.name, description: meta.description) { _ in
                // Empty body - execution not supported for decoded manifests
            }
        }
    }

    /// Encodes the Lanerfile as lane metadata.
    ///
    /// Only the lane names and descriptions are encoded.
    /// Execution closures cannot be serialized.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metadata, forKey: .lanes)
    }
}

// MARK: - Lane Metadata Conversion

public extension Lane {
    /// Returns metadata for this lane.
    var metadata: LaneMetadata {
        LaneMetadata(from: self)
    }
}
