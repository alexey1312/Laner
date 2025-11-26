import Logging

/// Categories for Swiftlane logging.
public enum LogCategory: String, Sendable, CaseIterable {
    /// Shell command execution logs.
    case shell

    /// Xcodebuild operation logs.
    case xcodebuild

    /// CLI command logs.
    case cli

    /// DSL execution logs.
    case dsl

    /// Configuration loading logs.
    case config

    /// Manifest compilation and loading logs.
    case manifest

    /// The logger label for this category.
    public var label: String {
        "swiftlane.\(rawValue)"
    }
}

extension Logger {
    /// Creates a logger for a specific Swiftlane category.
    /// - Parameter category: The log category.
    /// - Returns: A configured logger for the category.
    public static func swiftlane(_ category: LogCategory) -> Logger {
        Logger(label: category.label)
    }
}
