import Foundation

/// Errors that can occur during manifest compilation and loading.
public enum ManifestError: Error, Sendable, Equatable {
    /// The Lanerfile.swift was not found at the expected location.
    case notFound(path: URL)

    /// Compilation of the manifest failed.
    case compilationFailed(output: String)

    /// Execution of the compiled manifest failed.
    case executionFailed(output: String)

    /// The manifest produced invalid JSON output that could not be parsed.
    case invalidOutput(details: String)

    /// The Laner installation path could not be determined.
    case installPathNotFound

    /// The bundled DSL version does not match the binary version.
    case versionMismatch(expected: String, found: String)
}

extension ManifestError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .notFound(path):
            "Lanerfile.swift not found at: \(path.path)"
        case let .compilationFailed(output):
            "Failed to compile manifest:\n\(output)"
        case let .executionFailed(output):
            "Failed to execute manifest:\n\(output)"
        case let .invalidOutput(details):
            "Invalid manifest output: \(details)"
        case .installPathNotFound:
            "Could not determine Laner installation path"
        case let .versionMismatch(expected, found):
            "DSL version mismatch: expected \(expected), found \(found)"
        }
    }
}

extension ManifestError: LocalizedError {
    public var errorDescription: String? {
        description
    }
}
