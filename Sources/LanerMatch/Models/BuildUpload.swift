import Foundation

/// Represents a build upload session for Build Upload API v4.1+.
public struct BuildUpload: Codable, Sendable, Equatable {
    /// The unique identifier for the build upload session.
    public let id: String

    /// The current state of the upload.
    public let uploadState: UploadState

    /// Creates a new BuildUpload instance.
    public init(id: String, uploadState: UploadState) {
        self.id = id
        self.uploadState = uploadState
    }
}

// MARK: - UploadState

public extension BuildUpload {
    /// The state of a build upload session.
    enum UploadState: String, Codable, Sendable, Equatable {
        /// Upload is awaiting files.
        case awaitingFiles = "AWAITING_FILES"

        /// Upload is in progress.
        case uploading = "UPLOADING"

        /// Upload is complete.
        case complete = "COMPLETE"

        /// Upload failed.
        case failed = "FAILED"

        /// Unknown state (for forward compatibility).
        case unknown

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = UploadState(rawValue: rawValue) ?? .unknown
        }
    }
}

/// Represents a file reservation for chunked upload.
public struct BuildUploadFile: Codable, Sendable, Equatable {
    /// The unique identifier for the file.
    public let id: String

    /// The pre-signed URL to upload the file chunk to S3.
    public let uploadUrl: String

    /// The file ID for committing the chunk.
    public let fileId: String

    /// Creates a new BuildUploadFile instance.
    public init(id: String, uploadUrl: String, fileId: String) {
        self.id = id
        self.uploadUrl = uploadUrl
        self.fileId = fileId
    }
}

/// Information about a file chunk for upload.
public struct ChunkInfo: Sendable, Equatable {
    /// The chunk index (0-based).
    public let index: Int

    /// The byte offset in the file where this chunk starts.
    public let offset: Int64

    /// The size of this chunk in bytes.
    public let size: Int64

    /// The total file size in bytes.
    public let totalSize: Int64

    /// The MD5 checksum of the chunk data.
    public let checksum: String

    /// Creates a new ChunkInfo instance.
    public init(
        index: Int,
        offset: Int64,
        size: Int64,
        totalSize: Int64,
        checksum: String
    ) {
        self.index = index
        self.offset = offset
        self.size = size
        self.totalSize = totalSize
        self.checksum = checksum
    }
}
