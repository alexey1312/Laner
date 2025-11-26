import Foundation

/// An actor that executes shell commands asynchronously.
///
/// `ShellExecutor` provides safe, async execution of shell commands with support for:
/// - Capturing stdout and stderr
/// - Streaming output line-by-line
/// - Timeout handling
/// - Environment variable customization
/// - Working directory specification
public actor ShellExecutor {
    /// The default shell executor.
    public static let shared = ShellExecutor()

    /// The file manager used for executable lookup.
    private let fileManager: FileManager

    /// Creates a new shell executor.
    /// - Parameter fileManager: The file manager to use for executable lookup.
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Executes a command and returns the result after completion.
    /// - Parameters:
    ///   - command: The command to execute.
    ///   - arguments: The arguments to pass to the command.
    ///   - workingDirectory: The working directory for the command. Defaults to current directory.
    ///   - environment: Additional environment variables. Defaults to current environment.
    ///   - timeout: The maximum time to wait for the command. Defaults to 5 minutes.
    /// - Returns: The process result containing exit code, stdout, and stderr.
    /// - Throws: `ShellError` if the command fails or times out.
    public func run(
        _ command: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        timeout: Duration = .seconds(300)
    ) async throws -> ProcessResult {
        let startTime = ContinuousClock.now

        // Find the executable
        guard let executablePath = fileManager.findExecutable(command) else {
            throw ShellError.commandNotFound(command)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        // Merge environment
        var env = ProcessInfo.processInfo.environment
        if let additionalEnv = environment {
            for (key, value) in additionalEnv {
                env[key] = value
            }
        }
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Run with timeout
        do {
            try process.run()
        } catch {
            throw ShellError.setupFailed(error.localizedDescription)
        }

        // Create a task for the timeout
        let pid = process.processIdentifier
        let timeoutTask = Task {
            try await Task.sleep(for: timeout)
            // If we get here, the timeout expired
            kill(pid, SIGTERM)
            try await Task.sleep(for: .seconds(5))
            kill(pid, SIGKILL)
        }

        // Wait for process to complete
        process.waitUntilExit()
        timeoutTask.cancel()

        let duration = ContinuousClock.now - startTime

        // Check for timeout
        if process.terminationReason == .uncaughtSignal {
            let signal = process.terminationStatus
            if signal == SIGTERM || signal == SIGKILL {
                throw ShellError.timeout(command: command, after: timeout)
            }
            throw ShellError.signalTerminated(command: command, signal: signal)
        }

        // Read output
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        let exitCode = process.terminationStatus

        return ProcessResult(
            exitCode: exitCode,
            stdout: stdout.trimmingCharacters(in: .newlines),
            stderr: stderr.trimmingCharacters(in: .newlines),
            duration: duration
        )
    }

    /// Executes a command and streams output line-by-line.
    /// - Parameters:
    ///   - command: The command to execute.
    ///   - arguments: The arguments to pass to the command.
    ///   - workingDirectory: The working directory for the command. Defaults to current directory.
    ///   - environment: Additional environment variables. Defaults to current environment.
    ///   - timeout: The maximum time to wait for the command. Defaults to 5 minutes.
    /// - Returns: An async stream of output lines.
    public func stream(
        _ command: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        timeout: Duration = .seconds(300)
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Find the executable
                    guard let executablePath = fileManager.findExecutable(command) else {
                        continuation.finish(throwing: ShellError.commandNotFound(command))
                        return
                    }

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: executablePath)
                    process.arguments = arguments

                    if let workingDirectory {
                        process.currentDirectoryURL = workingDirectory
                    }

                    // Merge environment
                    var env = ProcessInfo.processInfo.environment
                    if let additionalEnv = environment {
                        for (key, value) in additionalEnv {
                            env[key] = value
                        }
                    }
                    process.environment = env

                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe

                    // Handle stdout
                    let stdoutHandle = stdoutPipe.fileHandleForReading
                    stdoutHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                            for line in str.components(separatedBy: .newlines) where !line.isEmpty {
                                continuation.yield(line)
                            }
                        }
                    }

                    // Handle stderr (also yield as output)
                    let stderrHandle = stderrPipe.fileHandleForReading
                    stderrHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                            for line in str.components(separatedBy: .newlines) where !line.isEmpty {
                                continuation.yield(line)
                            }
                        }
                    }

                    do {
                        try process.run()
                    } catch {
                        continuation.finish(throwing: ShellError.setupFailed(error.localizedDescription))
                        return
                    }

                    // Create a task for the timeout
                    let pid = process.processIdentifier
                    let timeoutTask = Task {
                        try await Task.sleep(for: timeout)
                        kill(pid, SIGTERM)
                        try await Task.sleep(for: .seconds(5))
                        kill(pid, SIGKILL)
                    }

                    // Wait for process to complete
                    process.waitUntilExit()
                    timeoutTask.cancel()

                    // Clean up handlers
                    stdoutHandle.readabilityHandler = nil
                    stderrHandle.readabilityHandler = nil

                    // Read any remaining data from pipes after process exits
                    // This is important on Linux where data may still be buffered
                    let remainingStdout = stdoutHandle.readDataToEndOfFile()
                    if !remainingStdout.isEmpty, let str = String(data: remainingStdout, encoding: .utf8) {
                        for line in str.components(separatedBy: .newlines) where !line.isEmpty {
                            continuation.yield(line)
                        }
                    }

                    let remainingStderr = stderrHandle.readDataToEndOfFile()
                    if !remainingStderr.isEmpty, let str = String(data: remainingStderr, encoding: .utf8) {
                        for line in str.components(separatedBy: .newlines) where !line.isEmpty {
                            continuation.yield(line)
                        }
                    }

                    // Check exit status
                    if process.terminationReason == .uncaughtSignal {
                        let signal = process.terminationStatus
                        if signal == SIGTERM || signal == SIGKILL {
                            continuation.finish(throwing: ShellError.timeout(command: command, after: timeout))
                        } else {
                            continuation.finish(throwing: ShellError.signalTerminated(command: command, signal: signal))
                        }
                        return
                    }

                    let exitCode = process.terminationStatus
                    if exitCode != 0 {
                        continuation.finish(throwing: ShellError.executionFailed(
                            command: command,
                            exitCode: exitCode,
                            stderr: ""
                        ))
                    } else {
                        continuation.finish()
                    }
                }
            }
        }
    }

    /// Executes a command and throws if it fails.
    /// - Parameters:
    ///   - command: The command to execute.
    ///   - arguments: The arguments to pass to the command.
    ///   - workingDirectory: The working directory for the command. Defaults to current directory.
    ///   - environment: Additional environment variables. Defaults to current environment.
    ///   - timeout: The maximum time to wait for the command. Defaults to 5 minutes.
    /// - Returns: The process result containing exit code, stdout, and stderr.
    /// - Throws: `ShellError.executionFailed` if the command exits with non-zero status.
    public func runOrThrow(
        _ command: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        timeout: Duration = .seconds(300)
    ) async throws -> ProcessResult {
        let result = try await run(
            command,
            arguments: arguments,
            workingDirectory: workingDirectory,
            environment: environment,
            timeout: timeout
        )

        if !result.isSuccess {
            throw ShellError.executionFailed(
                command: command,
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        return result
    }
}
