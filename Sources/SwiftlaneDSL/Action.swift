import Foundation

/// A protocol defining an executable CI/CD action.
///
/// Actions are the building blocks of lanes. Each action performs a specific
/// task such as building, testing, signing, or uploading.
///
/// ## Example
/// ```swift
/// struct BuildAction: Action {
///     typealias Options = BuildOptions
///     typealias Result = BuildResult
///
///     static let name = "build"
///
///     let options: BuildOptions
///
///     func execute(context: ExecutionContext) async throws -> BuildResult {
///         // Perform build using context.shell
///     }
/// }
/// ```
public protocol Action: Sendable {
    /// The type of options this action accepts.
    associatedtype Options: Sendable

    /// The type of result this action produces.
    associatedtype Result: Sendable

    /// The name of this action for logging and identification.
    static var name: String { get }

    /// A human-readable description of what this action does.
    static var description: String { get }

    /// Executes the action within the given context.
    /// - Parameter context: The execution context providing access to shell, logger, etc.
    /// - Returns: The result of the action.
    /// - Throws: Any error encountered during execution.
    @MainActor
    func execute(context: ExecutionContext) async throws -> Result
}

extension Action {
    /// Default description returns an empty string.
    public static var description: String { "" }
}

/// An action that produces no result.
public protocol VoidAction: Action where Result == Void {}

extension VoidAction {
    /// Convenience wrapper that ignores the void result.
    @MainActor
    public func run(context: ExecutionContext) async throws {
        _ = try await execute(context: context)
    }
}
