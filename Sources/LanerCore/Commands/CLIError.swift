import Foundation

/// Errors that can occur during CLI command execution.
public enum CLIError: Error, LocalizedError {
    /// No workspace or project found in the directory.
    case noProjectFound(in: URL)

    /// Could not discover scheme from project.
    case schemeDiscoveryFailed

    /// No scheme found in the project.
    case noSchemeFound

    /// Build failed with errors.
    case buildFailed(errors: [String])

    /// Test execution failed.
    case testFailed(failedTests: [String])

    /// Invalid argument provided.
    case invalidArgument(String)

    /// Required file not found.
    case fileNotFound(String)

    /// Operation not supported on this platform.
    case platformNotSupported(String)

    public var errorDescription: String? {
        switch self {
        case let .noProjectFound(url):
            return "No .xcworkspace or .xcodeproj found in '\(url.path(percentEncoded: false))'"
        case .schemeDiscoveryFailed:
            return "Failed to discover available schemes. Specify --scheme explicitly."
        case .noSchemeFound:
            return "No schemes found in the project. Specify --scheme explicitly."
        case let .buildFailed(errors):
            if errors.isEmpty {
                return "Build failed"
            }
            return "Build failed with \(errors.count) error(s)"
        case let .testFailed(failedTests):
            if failedTests.isEmpty {
                return "Tests failed"
            }
            return "\(failedTests.count) test(s) failed"
        case let .invalidArgument(message):
            return "Invalid argument: \(message)"
        case let .fileNotFound(path):
            return "File not found: \(path)"
        case let .platformNotSupported(feature):
            return "\(feature) is only available on macOS"
        }
    }
}

/// Exit codes for CLI commands.
public enum LanerExitCode: Int32 {
    /// Command completed successfully.
    case success = 0

    /// General failure.
    case failure = 1

    /// Build failure.
    case buildFailure = 2

    /// Test failure.
    case testFailure = 3

    /// Invalid usage/arguments (EX_USAGE).
    case invalidUsage = 64

    /// Configuration error.
    case configurationError = 78
}
