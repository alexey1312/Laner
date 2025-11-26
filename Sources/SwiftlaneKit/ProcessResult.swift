import Foundation

/// The result of executing a shell process.
public struct ProcessResult: Sendable, Equatable {
    /// The exit code from the process.
    public let exitCode: Int32

    /// The standard output captured from the process.
    public let stdout: String

    /// The standard error output captured from the process.
    public let stderr: String

    /// The duration the process took to execute.
    public let duration: Duration

    /// Creates a new process result.
    /// - Parameters:
    ///   - exitCode: The exit code from the process.
    ///   - stdout: The standard output captured from the process.
    ///   - stderr: The standard error output captured from the process.
    ///   - duration: The duration the process took to execute.
    public init(exitCode: Int32, stdout: String, stderr: String, duration: Duration) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.duration = duration
    }

    /// Whether the process completed successfully (exit code 0).
    public var isSuccess: Bool {
        exitCode == 0
    }

    /// The combined output (stdout + stderr).
    public var combinedOutput: String {
        if stdout.isEmpty {
            return stderr
        }
        if stderr.isEmpty {
            return stdout
        }
        return stdout + "\n" + stderr
    }
}
