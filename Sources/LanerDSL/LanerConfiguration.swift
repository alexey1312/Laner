import Foundation
import Logging

/// A protocol for user-defined Laner configuration files.
///
/// Implement this protocol in your `Lanerfile.swift` to define
/// your project's CI/CD lanes.
///
/// ## Example
/// ```swift
/// // Lanerfile.swift
/// import LanerDSL
///
/// struct MyLanerfile: LanerConfiguration {
///     static var lanes: [Lane] {
///         [
///             Lane(name: "build") { context in
///                 // Build actions
///             },
///             Lane(name: "test") { context in
///                 // Test actions
///             },
///             Lane(name: "deploy") { context in
///                 // Deployment actions
///             }
///         ]
///     }
///
///     static func beforeAll(lane: Lane) async {
///         print("Starting \(lane.name)...")
///     }
///
///     static func afterAll(lane: Lane, result: LaneResult) async {
///         print("Finished \(lane.name): \(result.success ? "success" : "failure")")
///     }
/// }
/// ```
public protocol LanerConfiguration {
    /// The lanes defined by this configuration.
    static var lanes: [Lane] { get }

    /// Called before any lane executes.
    /// - Parameter lane: The lane about to execute.
    @MainActor
    static func beforeAll(lane: Lane) async

    /// Called after any lane completes (success or failure).
    /// - Parameters:
    ///   - lane: The lane that completed.
    ///   - result: The result of lane execution.
    @MainActor
    static func afterAll(lane: Lane, result: LaneResult) async

    /// Called when a lane fails with an error.
    /// - Parameters:
    ///   - lane: The lane that failed.
    ///   - error: The error that caused the failure.
    @MainActor
    static func onError(lane: Lane, error: any Error) async
}

// MARK: - Default Implementations

extension LanerConfiguration {
    public static func beforeAll(lane: Lane) async {
        // Default: no-op
    }

    public static func afterAll(lane: Lane, result: LaneResult) async {
        // Default: no-op
    }

    public static func onError(lane: Lane, error: any Error) async {
        // Default: no-op
    }
}

// MARK: - Configuration Helpers

extension LanerConfiguration {
    /// Finds a lane by name.
    /// - Parameter name: The lane name to find.
    /// - Returns: The lane if found, or nil.
    public static func lane(named name: String) -> Lane? {
        lanes.first { $0.name == name }
    }

    /// Validates that all lane names are unique.
    /// - Throws: `ConfigurationError.duplicateLaneName` if duplicates exist.
    public static func validate() throws {
        var seen = Set<String>()
        for lane in lanes {
            if seen.contains(lane.name) {
                throw ConfigurationError.duplicateLaneName(lane.name)
            }
            seen.insert(lane.name)
        }
    }

    /// Executes a lane by name with the given configuration hooks.
    /// - Parameters:
    ///   - name: The name of the lane to execute.
    ///   - context: The execution context.
    /// - Returns: The result of lane execution.
    /// - Throws: `ConfigurationError.laneNotFound` if no lane matches.
    @MainActor
    public static func runLane(
        named name: String,
        context: ExecutionContext? = nil
    ) async throws -> LaneResult {
        guard let lane = lane(named: name) else {
            throw ConfigurationError.laneNotFound(name)
        }

        let executionContext = context ?? ExecutionContext()
        let startTime = ContinuousClock.now

        // beforeAll hook
        await beforeAll(lane: lane)

        do {
            try await lane.execute(context: executionContext)

            let duration = ContinuousClock.now - startTime
            let artifacts = await executionContext.artifacts.all()

            let result = LaneResult.success(
                laneName: lane.name,
                duration: duration,
                artifacts: artifacts
            )

            // afterAll hook
            await afterAll(lane: lane, result: result)

            return result
        } catch {
            let duration = ContinuousClock.now - startTime
            let artifacts = await executionContext.artifacts.all()

            let result = LaneResult.failure(
                laneName: lane.name,
                duration: duration,
                error: error,
                artifacts: artifacts
            )

            // onError hook
            await onError(lane: lane, error: error)

            // afterAll hook (also called on failure)
            await afterAll(lane: lane, result: result)

            return result
        }
    }
}

/// Errors related to configuration.
public enum ConfigurationError: Error, LocalizedError {
    /// A lane with the specified name was not found.
    case laneNotFound(String)

    /// Multiple lanes have the same name.
    case duplicateLaneName(String)

    /// The Lanerfile could not be loaded.
    case loadFailed(String)

    public var errorDescription: String? {
        switch self {
        case .laneNotFound(let name):
            return "Lane '\(name)' not found. Run 'laner lanes' to see available lanes."
        case .duplicateLaneName(let name):
            return "Duplicate lane name '\(name)'. Lane names must be unique."
        case .loadFailed(let reason):
            return "Failed to load Lanerfile: \(reason)"
        }
    }
}
