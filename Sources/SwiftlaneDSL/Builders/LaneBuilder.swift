import Foundation

/// A result builder for constructing arrays of actions declaratively.
///
/// `LaneBuilder` enables a DSL-style syntax for defining sequences of actions
/// within lanes. It supports standard Swift control flow including conditionals,
/// loops, and optional actions.
///
/// ## Example
/// ```swift
/// Lane("build") {
///     AnyAction(gym(scheme: "App", configuration: .debug))
///     AnyAction(scan(scheme: "AppTests", codeCoverage: true))
/// }
/// ```
///
/// ## Control Flow Support
/// ```swift
/// Lane("conditional") {
///     if shouldRunTests {
///         AnyAction(scan(scheme: "Tests"))
///     } else {
///         AnyAction(echo("Skipping tests"))
///     }
///
///     for target in targets {
///         AnyAction(buildTarget(target))
///     }
/// }
/// ```
@resultBuilder
public struct LaneBuilder: Sendable {
    /// Builds a block of actions into an array.
    /// - Parameter components: The action arrays to combine.
    /// - Returns: A flattened array containing all actions.
    public static func buildBlock(_ components: [AnyAction]...) -> [AnyAction] {
        components.flatMap { $0 }
    }

    /// Builds an optional action.
    /// - Parameter component: The optional array of actions.
    /// - Returns: The unwrapped actions, or an empty array if nil.
    public static func buildOptional(_ component: [AnyAction]?) -> [AnyAction] {
        component ?? []
    }

    /// Builds the first branch of a conditional.
    /// - Parameter component: The actions from the first branch.
    /// - Returns: The actions array.
    public static func buildEither(first component: [AnyAction]) -> [AnyAction] {
        component
    }

    /// Builds the second branch of a conditional.
    /// - Parameter component: The actions from the second branch.
    /// - Returns: The actions array.
    public static func buildEither(second component: [AnyAction]) -> [AnyAction] {
        component
    }

    /// Builds an array from a collection of action arrays (for loops).
    /// - Parameter components: The arrays of actions to flatten.
    /// - Returns: A flattened array of all actions.
    public static func buildArray(_ components: [[AnyAction]]) -> [AnyAction] {
        components.flatMap { $0 }
    }

    /// Builds an action array from a single action expression.
    /// - Parameter expression: A single action.
    /// - Returns: An array containing the action.
    public static func buildExpression(_ expression: AnyAction) -> [AnyAction] {
        [expression]
    }

    /// Builds an action array from an array expression.
    /// - Parameter expression: An array of actions.
    /// - Returns: The actions array.
    public static func buildExpression(_ expression: [AnyAction]) -> [AnyAction] {
        expression
    }

    /// Builds a limited availability action (availability conditionals).
    /// - Parameter component: The actions from the availability block.
    /// - Returns: The actions array.
    public static func buildLimitedAvailability(_ component: [AnyAction]) -> [AnyAction] {
        component
    }
}
