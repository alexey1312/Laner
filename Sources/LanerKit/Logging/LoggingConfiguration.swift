import Foundation
import Logging

/// Verbosity level for CLI output.
public enum Verbosity: Sendable {
    /// Minimal output (errors and critical only).
    case quiet

    /// Normal output (info and above).
    case normal

    /// Verbose output (debug and above).
    case verbose

    /// Very verbose output (trace and above).
    case trace

    /// The corresponding swift-log level.
    public var logLevel: Logger.Level {
        switch self {
        case .quiet:
            return .warning
        case .normal:
            return .info
        case .verbose:
            return .debug
        case .trace:
            return .trace
        }
    }
}

/// Configuration for Laner logging.
public enum LoggingConfiguration {
    /// Atomic flag for whether logging has been bootstrapped.
    private static let isBootstrapped = LockedState(initialState: false)

    /// Bootstraps the logging system with console output.
    /// - Parameters:
    ///   - verbosity: The verbosity level for output.
    ///   - useColors: Whether to use colors. Defaults to auto-detection.
    public static func bootstrap(verbosity: Verbosity = .normal, useColors: Bool? = nil) {
        let alreadyBootstrapped = isBootstrapped.withLock { bootstrapped in
            if bootstrapped {
                return true
            }
            bootstrapped = true
            return false
        }

        guard !alreadyBootstrapped else { return }

        let level = verbosity.logLevel

        LoggingSystem.bootstrap { label in
            var handler = ConsoleLogHandler(label: label, useColors: useColors)
            handler.logLevel = level
            return handler
        }
    }

    /// Updates the log level for all handlers.
    /// - Parameter verbosity: The new verbosity level.
    /// - Note: This only affects newly created loggers. Existing loggers keep their level.
    public static func setVerbosity(_ verbosity: Verbosity) {
        // Note: swift-log doesn't support changing the level globally after bootstrap.
        // This would require a custom log handler that reads the level from a shared source.
    }
}

/// A simple thread-safe container for mutable state.
private final class LockedState<T>: @unchecked Sendable {
    private var _value: T
    private let lock = NSLock()

    init(initialState: T) {
        self._value = initialState
    }

    func withLock<R>(_ body: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&_value)
    }
}
