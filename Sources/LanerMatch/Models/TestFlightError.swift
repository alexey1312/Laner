import Foundation

/// Errors that can occur during TestFlight operations.
public enum TestFlightError: Error, LocalizedError, Sendable, Equatable {
    /// The IPA file was not found at the specified path.
    case ipaNotFound(String)

    /// The IPA file is invalid or corrupted.
    case invalidIPA(String)

    /// Failed to create the build upload session.
    case uploadCreationFailed(String)

    /// Failed to upload a file chunk.
    case chunkUploadFailed(chunkIndex: Int, reason: String)

    /// Failed to complete the build upload.
    case uploadCompletionFailed(String)

    /// The build processing timed out.
    case processingTimeout

    /// The build failed processing.
    case processingFailed(String)

    /// The specified beta group was not found.
    case groupNotFound(String)

    /// Failed to add build to beta group.
    case distributionFailed(String)

    /// The API returned a rate limit response.
    case rateLimited(retryAfter: Int)

    /// An App Store Connect API error occurred.
    case apiError(String)

    /// The app ID is required but not provided.
    case missingAppId

    /// The API credentials are not configured.
    case missingCredentials(String)

    /// Platform not supported for this operation.
    case platformNotSupported

    public var errorDescription: String? {
        switch self {
        case let .ipaNotFound(path):
            "IPA file not found: \(path)"
        case let .invalidIPA(reason):
            "Invalid IPA file: \(reason)"
        case let .uploadCreationFailed(reason):
            "Failed to create upload session: \(reason)"
        case let .chunkUploadFailed(index, reason):
            "Failed to upload chunk \(index): \(reason)"
        case let .uploadCompletionFailed(reason):
            "Failed to complete upload: \(reason)"
        case .processingTimeout:
            "Build processing timed out (30 minutes)"
        case let .processingFailed(reason):
            "Build processing failed: \(reason)"
        case let .groupNotFound(name):
            "Beta group not found: \(name)"
        case let .distributionFailed(reason):
            "Failed to distribute build: \(reason)"
        case let .rateLimited(retryAfter):
            "Rate limited by App Store Connect. Retry after \(retryAfter) seconds."
        case let .apiError(reason):
            "App Store Connect API error: \(reason)"
        case .missingAppId:
            "App ID is required. Provide via --app-id or APP_STORE_APP_ID environment variable."
        case let .missingCredentials(missing):
            "Missing API credentials: \(missing)"
        case .platformNotSupported:
            "TestFlight upload is only supported on macOS"
        }
    }
}

/// Progress information for upload operations.
public struct UploadProgress: Sendable, Equatable {
    /// The number of bytes uploaded so far.
    public let bytesUploaded: Int64

    /// The total number of bytes to upload.
    public let totalBytes: Int64

    /// The current chunk being uploaded (0-based).
    public let currentChunk: Int

    /// The total number of chunks.
    public let totalChunks: Int

    /// The upload percentage (0-100).
    public var percentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesUploaded) / Double(totalBytes) * 100
    }

    /// Creates a new UploadProgress instance.
    public init(
        bytesUploaded: Int64,
        totalBytes: Int64,
        currentChunk: Int,
        totalChunks: Int
    ) {
        self.bytesUploaded = bytesUploaded
        self.totalBytes = totalBytes
        self.currentChunk = currentChunk
        self.totalChunks = totalChunks
    }
}
