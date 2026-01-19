import Foundation
import Logging

/// A log handler that outputs to the console with color support.
public struct ConsoleLogHandler: LogHandler {
    /// The label for this handler.
    public let label: String

    /// The current log level.
    public var logLevel: Logger.Level = .info

    /// Metadata for this handler.
    public var metadata: Logger.Metadata = [:]

    /// Whether to use colors in output.
    private let useColors: Bool

    /// Creates a new console log handler.
    /// - Parameters:
    ///   - label: The label for this handler.
    ///   - useColors: Whether to use ANSI colors in output. Defaults to auto-detection.
    public init(label: String, useColors: Bool? = nil) {
        self.label = label
        self.useColors = useColors ?? Self.shouldUseColors()
    }

    /// Subscript for metadata values.
    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    /// Logs a message.
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let timestamp = Self.timestampFormatter.string(from: Date())
        let levelString = Self.levelString(level, useColors: useColors)
        let categoryString = Self.categoryString(from: label)

        let output = "[\(timestamp)] \(levelString) \(categoryString): \(message)"

        // Print to appropriate stream
        if level >= .warning {
            FileHandle.standardError.write(Data((output + "\n").utf8))
        } else {
            print(output)
        }
    }

    // MARK: - Private Helpers

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static func shouldUseColors() -> Bool {
        // Disable colors in CI or if not a TTY
        if Platform.isCI {
            return false
        }

        // Check if stdout is a terminal
        return isatty(STDOUT_FILENO) != 0
    }

    private static func levelString(_ level: Logger.Level, useColors: Bool) -> String {
        let (symbol, color) = levelSymbolAndColor(level)

        if useColors {
            return "\(color)\(symbol)\(ANSIColor.reset)"
        } else {
            return symbol
        }
    }

    private static func levelSymbolAndColor(_ level: Logger.Level) -> (String, String) {
        switch level {
        case .trace:
            ("TRACE", ANSIColor.gray)
        case .debug:
            ("DEBUG", ANSIColor.gray)
        case .info:
            ("INFO ", ANSIColor.blue)
        case .notice:
            ("NOTE ", ANSIColor.cyan)
        case .warning:
            ("WARN ", ANSIColor.yellow)
        case .error:
            ("ERROR", ANSIColor.red)
        case .critical:
            ("CRIT ", ANSIColor.brightRed)
        }
    }

    private static func categoryString(from label: String) -> String {
        // Extract category from "laner.category"
        if label.hasPrefix("laner.") {
            return String(label.dropFirst("laner.".count))
        }
        return label
    }
}

// MARK: - ANSI Colors

private enum ANSIColor {
    static let reset = "\u{001B}[0m"
    static let gray = "\u{001B}[90m"
    static let blue = "\u{001B}[34m"
    static let cyan = "\u{001B}[36m"
    static let yellow = "\u{001B}[33m"
    static let red = "\u{001B}[31m"
    static let brightRed = "\u{001B}[91m"
    static let green = "\u{001B}[32m"
}
