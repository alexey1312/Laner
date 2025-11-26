import Foundation
import Logging
import SwiftlaneKit

/// Provides the execution environment for actions within a lane.
///
/// `ExecutionContext` is an actor that provides thread-safe access to:
/// - Shell command execution
/// - Logging
/// - Environment variables
/// - Artifact storage
/// - File system operations
///
/// ## Example
/// ```swift
/// func execute(context: ExecutionContext) async throws -> BuildResult {
///     let logger = await context.logger
///     logger.info("Starting build...")
///
///     let result = try await context.shell.run("xcodebuild", arguments: ["-project", "App.xcodeproj"])
///
///     if result.isSuccess {
///         await context.addArtifact(Artifact(type: .app, path: appURL))
///     }
///
///     return BuildResult(success: result.isSuccess)
/// }
/// ```
@MainActor
public final class ExecutionContext: Sendable {
    /// The execution environment with CI detection and environment variables.
    public let environment: Environment

    /// The logger for this execution context.
    public let logger: Logger

    /// The file manager for file system operations.
    /// Access this from nonisolated contexts using the local FileManager.default.
    private let _fileManager: FileManager

    /// Provides access to file manager for isolated contexts.
    public var fileManager: FileManager { _fileManager }

    /// The shell executor for running commands.
    public let shell: ShellExecutor

    /// The artifact store for collecting build outputs.
    public let artifacts: ArtifactStore

    /// The current working directory for this context.
    public let workingDirectory: URL

    /// Optional parameters passed to the lane.
    public let parameters: [String: Any]

    /// Creates a new execution context.
    /// - Parameters:
    ///   - environment: The execution environment. Defaults to current environment.
    ///   - logger: The logger to use. Defaults to a new swiftlane logger.
    ///   - fileManager: The file manager. Defaults to `.default`.
    ///   - shell: The shell executor. Defaults to shared instance.
    ///   - workingDirectory: The working directory. Defaults to current directory.
    ///   - parameters: Optional lane parameters.
    public init(
        environment: Environment = Environment(),
        logger: Logger = Logger.swiftlane(.dsl),
        fileManager: FileManager = .default,
        shell: ShellExecutor = .shared,
        workingDirectory: URL? = nil,
        parameters: [String: Any] = [:]
    ) {
        self.environment = environment
        self.logger = logger
        self._fileManager = fileManager
        self.shell = shell
        self.artifacts = ArtifactStore()
        self.workingDirectory = workingDirectory ?? environment.workingDirectory
        self.parameters = parameters
    }

    /// Adds an artifact to the store.
    /// - Parameter artifact: The artifact to add.
    public func addArtifact(_ artifact: Artifact) async {
        await artifacts.add(artifact)
    }

    /// Gets a parameter value by key.
    /// - Parameter key: The parameter key.
    /// - Returns: The value if present and of the correct type.
    public func parameter<T>(_ key: String) -> T? {
        parameters[key] as? T
    }

    /// Gets a required parameter value.
    /// - Parameter key: The parameter key.
    /// - Returns: The value.
    /// - Throws: `ContextError.missingParameter` if not present.
    public func requireParameter<T>(_ key: String) throws -> T {
        guard let value = parameters[key] as? T else {
            throw ContextError.missingParameter(key)
        }
        return value
    }

    /// Creates a sub-context with a different working directory.
    /// - Parameter directory: The new working directory.
    /// - Returns: A new context with the updated working directory.
    public func withWorkingDirectory(_ directory: URL) -> ExecutionContext {
        ExecutionContext(
            environment: environment,
            logger: logger,
            fileManager: _fileManager,
            shell: shell,
            workingDirectory: directory,
            parameters: parameters
        )
    }

    /// Creates a sub-context with additional parameters.
    /// - Parameter additionalParameters: Parameters to add.
    /// - Returns: A new context with merged parameters.
    public func withParameters(_ additionalParameters: [String: Any]) -> ExecutionContext {
        var merged = parameters
        for (key, value) in additionalParameters {
            merged[key] = value
        }
        return ExecutionContext(
            environment: environment,
            logger: logger,
            fileManager: _fileManager,
            shell: shell,
            workingDirectory: workingDirectory,
            parameters: merged
        )
    }
}

/// Errors related to execution context.
public enum ContextError: Error, LocalizedError {
    /// A required parameter is missing.
    case missingParameter(String)

    /// A parameter has an unexpected type.
    case invalidParameterType(key: String, expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case .missingParameter(let key):
            return "Required parameter '\(key)' is not provided"
        case .invalidParameterType(let key, let expected, let actual):
            return "Parameter '\(key)' has type '\(actual)' but expected '\(expected)'"
        }
    }
}
