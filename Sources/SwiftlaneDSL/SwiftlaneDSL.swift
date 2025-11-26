// SwiftlaneDSL - Public DSL API for Swiftlane
// This module provides the domain-specific language for defining lanes and actions.

import Foundation
import Logging
@_exported import SwiftlaneKit
@_exported import SwiftlaneMatch

// Re-export all public types from the DSL module.
// Users only need to `import SwiftlaneDSL` to access the full API.

// MARK: - Convenience Logger Extension

extension Logger {
    /// Creates a logger for DSL operations.
    public static var dsl: Logger {
        Logger.swiftlane(.dsl)
    }
}
