import Foundation
import LanerKit
import Logging

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

/// A runner that executes Pkl-defined lanes via ActionDispatcher.
public struct LaneRunner: Sendable {
    private let logger: Logger
    private let dispatcher: ActionDispatcher

    /// Creates a new lane runner.
    /// - Parameter logger: The logger to use for execution output.
    public init(logger: Logger = Logger.laner(.dsl)) {
        self.logger = logger
        dispatcher = ActionDispatcher(logger: logger)
    }

    /// Executes a Pkl lane and returns the result.
    /// - Parameters:
    ///   - lane: The Pkl lane to execute.
    ///   - context: The execution context. If nil, a new one is created.
    /// - Returns: The result of lane execution.
    @MainActor
    public func run(
        _ lane: Lanerfile.Lane,
        context: ExecutionContext? = nil
    ) async -> LaneResult {
        let executionContext = context ?? ExecutionContext(logger: logger)
        let startTime = ContinuousClock.now

        logger.info("Starting lane: \(lane.name)")

        do {
            try await dispatcher.executeLane(lane, context: executionContext)

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
