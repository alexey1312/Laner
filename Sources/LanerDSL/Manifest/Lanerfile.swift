import Foundation

// MARK: - Lanerfile.Module Convenience Extensions

public extension Lanerfile.Module {
    /// Looks up a lane by name.
    /// - Parameter name: The name of the lane to find.
    /// - Returns: The lane with the given name, or nil if not found.
    func lane(named name: String) -> Lanerfile.Lane? {
        lanes.first { $0.name == name }
    }

    /// Returns all lane names defined in this manifest.
    var laneNames: [String] {
        lanes.map(\.name)
    }
}
