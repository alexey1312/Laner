// LanerDSL - Public DSL API for Laner
// This module provides the domain-specific language for defining lanes and actions.

import Foundation
@_exported import LanerKit
@_exported import LanerMatch
import Logging

// Re-export all public types from the DSL module.
// Users only need to `import LanerDSL` to access the full API.

// MARK: - Convenience Logger Extension

public extension Logger {
    /// Creates a logger for DSL operations.
    static var dsl: Logger {
        Logger.laner(.dsl)
    }
}
