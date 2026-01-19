import Foundation

/// A type-erased wrapper for any action.
///
/// `AnyAction` allows storing heterogeneous actions in collections
/// while preserving their execution capability.
///
/// ## Example
/// ```swift
/// let actions: [AnyAction] = [
///     AnyAction(BuildAction(options: .default)),
///     AnyAction(TestAction(options: .default))
/// ]
///
/// for action in actions {
///     try await action.execute(context: context)
/// }
/// ```
public struct AnyAction: Sendable {
    /// The name of the wrapped action.
    public let name: String

    /// The description of the wrapped action.
    public let description: String

    /// The type-erased execution closure.
    private let _execute: @MainActor @Sendable (ExecutionContext) async throws -> Void

    /// Creates a type-erased action from any concrete action.
    /// - Parameter action: The action to wrap.
    public init<A: Action>(_ action: A) {
        name = A.name
        description = A.description
        _execute = { context in
            _ = try await action.execute(context: context)
        }
    }

    /// Executes the wrapped action.
    /// - Parameter context: The execution context.
    /// - Throws: Any error from the underlying action.
    @MainActor
    public func execute(context: ExecutionContext) async throws {
        try await _execute(context)
    }
}

/// A type-erased wrapper for actions that returns a specific result type.
///
/// Use this when you need to preserve the result type of the action.
public struct AnyTypedAction<Result: Sendable>: Sendable {
    /// The name of the wrapped action.
    public let name: String

    /// The description of the wrapped action.
    public let description: String

    /// The type-erased execution closure.
    private let _execute: @MainActor @Sendable (ExecutionContext) async throws -> Result

    /// Creates a type-erased action from any concrete action with a matching result type.
    /// - Parameter action: The action to wrap.
    public init<A: Action>(_ action: A) where A.Result == Result {
        name = A.name
        description = A.description
        _execute = { context in
            try await action.execute(context: context)
        }
    }

    /// Executes the wrapped action.
    /// - Parameter context: The execution context.
    /// - Returns: The result of the action.
    /// - Throws: Any error from the underlying action.
    @MainActor
    public func execute(context: ExecutionContext) async throws -> Result {
        try await _execute(context)
    }
}
