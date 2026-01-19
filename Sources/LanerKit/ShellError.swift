import Foundation

/// Errors that can occur during shell command execution.
public enum ShellError: Error, Sendable, Equatable {
    /// The command executable was not found.
    case commandNotFound(String)

    /// The command execution timed out.
    case timeout(command: String, after: Duration)

    /// The command failed with a non-zero exit code.
    case executionFailed(command: String, exitCode: Int32, stderr: String)

    /// The process was terminated by a signal.
    case signalTerminated(command: String, signal: Int32)

    /// An error occurred while setting up the process.
    case setupFailed(String)
}

extension ShellError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .commandNotFound(command):
            return "Command not found: \(command)"
        case let .timeout(command, duration):
            return "Command '\(command)' timed out after \(duration)"
        case let .executionFailed(command, exitCode, stderr):
            let stderrSuffix = stderr.isEmpty ? "" : ": \(stderr)"
            return "Command '\(command)' failed with exit code \(exitCode)\(stderrSuffix)"
        case let .signalTerminated(command, signal):
            return "Command '\(command)' was terminated by signal \(signal)"
        case let .setupFailed(message):
            return "Process setup failed: \(message)"
        }
    }
}

extension ShellError: LocalizedError {
    public var errorDescription: String? {
        description
    }
}
