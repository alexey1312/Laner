import Foundation
import Logging
import SwiftlaneKit

/// Represents a CI/CD lane containing a sequence of actions.
///
/// A lane is a named workflow that executes a series of actions in order.
/// Lanes are the primary unit of execution in Swiftlane.
///
/// ## Example
/// ```swift
/// let buildLane = Lane(
///     name: "build",
///     description: "Builds the iOS app for testing"
/// ) { context in
///     try await BuildAction(options: .init(configuration: .debug)).execute(context: context)
///     try await TestAction(options: .init()).execute(context: context)
/// }
/// ```
public struct Lane: Sendable {
    /// The unique name of this lane.
    public let name: String

    /// A human-readable description of what this lane does.
    public let description: String

    /// The execution closure that runs the lane's actions.
    private let body: @MainActor @Sendable (ExecutionContext) async throws -> Void

    /// Creates a new lane with a name and execution body.
    /// - Parameters:
    ///   - name: The unique name for this lane.
    ///   - description: A description of what this lane does. Defaults to empty.
    ///   - body: The closure containing the lane's actions.
    public init(
        name: String,
        description: String = "",
        body: @MainActor @escaping @Sendable (ExecutionContext) async throws -> Void
    ) {
        self.name = name
        self.description = description
        self.body = body
    }

    /// Creates a new lane from a sequence of actions.
    /// - Parameters:
    ///   - name: The unique name for this lane.
    ///   - description: A description of what this lane does.
    ///   - actions: The actions to execute in order.
    public init(
        name: String,
        description: String = "",
        actions: [AnyAction]
    ) {
        self.name = name
        self.description = description
        self.body = { context in
            for action in actions {
                try await action.execute(context: context)
            }
        }
    }

    /// Creates a new lane using a result builder for declarative action composition.
    /// - Parameters:
    ///   - name: The unique name for this lane.
    ///   - description: A description of what this lane does.
    ///   - actions: A result builder closure that constructs the actions.
    ///
    /// ## Example
    /// ```swift
    /// Lane("build") {
    ///     AnyAction(gym(scheme: "App", configuration: .debug))
    ///     AnyAction(scan(scheme: "AppTests", codeCoverage: true))
    /// }
    /// ```
    public init(
        _ name: String,
        description: String = "",
        @LaneBuilder actions: () -> [AnyAction]
    ) {
        self.name = name
        self.description = description
        let actionArray = actions()
        self.body = { context in
            for action in actionArray {
                try await action.execute(context: context)
            }
        }
    }

    /// Executes the lane within the given context.
    /// - Parameter context: The execution context.
    /// - Throws: Any error from the lane's actions.
    @MainActor
    public func execute(context: ExecutionContext) async throws {
        try await body(context)
    }
}

/// Result of lane execution.
public struct LaneResult: Sendable {
    /// The name of the lane that was executed.
    public let laneName: String

    /// Whether the lane completed successfully.
    public let success: Bool

    /// The duration of lane execution.
    public let duration: Duration

    /// Any error that occurred, if the lane failed.
    public let error: (any Error)?

    /// Artifacts produced during execution.
    public let artifacts: [Artifact]

    /// Creates a successful lane result.
    public static func success(
        laneName: String,
        duration: Duration,
        artifacts: [Artifact] = []
    ) -> LaneResult {
        LaneResult(
            laneName: laneName,
            success: true,
            duration: duration,
            error: nil,
            artifacts: artifacts
        )
    }

    /// Creates a failed lane result.
    public static func failure(
        laneName: String,
        duration: Duration,
        error: any Error,
        artifacts: [Artifact] = []
    ) -> LaneResult {
        LaneResult(
            laneName: laneName,
            success: false,
            duration: duration,
            error: error,
            artifacts: artifacts
        )
    }
}

/// A runner that executes lanes with proper setup and teardown.
public struct LaneRunner: Sendable {
    private let logger: Logger

    /// Creates a new lane runner.
    /// - Parameter logger: The logger to use for execution output.
    public init(logger: Logger = Logger.swiftlane(.dsl)) {
        self.logger = logger
    }

    /// Executes a lane and returns the result.
    /// - Parameters:
    ///   - lane: The lane to execute.
    ///   - context: The execution context. If nil, a new one is created.
    /// - Returns: The result of lane execution.
    @MainActor
    public func run(
        _ lane: Lane,
        context: ExecutionContext? = nil
    ) async -> LaneResult {
        let executionContext = context ?? ExecutionContext(logger: logger)
        let startTime = ContinuousClock.now

        logger.info("Starting lane: \(lane.name)")

        do {
            try await lane.execute(context: executionContext)

            let duration = ContinuousClock.now - startTime
            let artifacts = await executionContext.artifacts.all()

            logger.info("Lane '\(lane.name)' completed successfully in \(duration.formatted())")

            return .success(
                laneName: lane.name,
                duration: duration,
                artifacts: artifacts
            )
        } catch {
            let duration = ContinuousClock.now - startTime
            let artifacts = await executionContext.artifacts.all()

            logger.error("Lane '\(lane.name)' failed: \(error.localizedDescription)")

            return .failure(
                laneName: lane.name,
                duration: duration,
                error: error,
                artifacts: artifacts
            )
        }
    }
}

extension Duration {
    func formatted() -> String {
        let totalSeconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        if totalSeconds < 1 {
            return String(format: "%.0fms", totalSeconds * 1000)
        } else if totalSeconds < 60 {
            return String(format: "%.1fs", totalSeconds)
        } else {
            let minutes = Int(totalSeconds) / 60
            let seconds = Int(totalSeconds) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}
