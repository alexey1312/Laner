import Foundation

/// Errors that can occur during manifest loading and evaluation.
public enum ManifestError: Error, Sendable, Equatable {
    /// The Lanerfile.pkl was not found at the expected location.
    case notFound(path: URL)

    /// Pkl evaluation of the manifest failed.
    case evaluationFailed(details: String)

    /// The bundled DSL version does not match the binary version.
    case versionMismatch(expected: String, found: String)
}

extension ManifestError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .notFound(path):
            "Lanerfile.pkl not found at: \(path.path)"
        case let .evaluationFailed(details):
            "Failed to evaluate manifest:\n\(details)"
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
