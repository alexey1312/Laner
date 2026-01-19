import AsyncHTTPClient
import Crypto
import Foundation
import Logging
import NIOCore
import NIOHTTP1

/// Actor responsible for chunked file uploads to App Store Connect.
///
/// Uses the Build Upload API v4.1+ with chunked uploads for large files.
/// Each chunk is uploaded to a pre-signed S3 URL provided by the API.
public actor ChunkedUploader {
    /// The default chunk size (50 MB).
    public static let defaultChunkSize: Int = 50 * 1024 * 1024

    /// Maximum number of retry attempts per chunk.
    public static let maxRetries: Int = 3

    private let api: AppStoreConnectAPI
    private let httpClient: HTTPClient
    private let chunkSize: Int
    private let logger: Logger

    /// Initializes a new ChunkedUploader.
    /// - Parameters:
    ///   - api: The App Store Connect API client.
    ///   - chunkSize: The size of each chunk in bytes (default: 50 MB).
    public init(
        api: AppStoreConnectAPI,
        chunkSize: Int = ChunkedUploader.defaultChunkSize
    ) {
        self.api = api
        httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        self.chunkSize = chunkSize
        logger = Logger(label: "com.laner.match.uploader")
    }

    /// Shuts down the HTTP client.
    public func shutdown() async throws {
        try await httpClient.shutdown()
    }

    /// Uploads an IPA file to App Store Connect using chunked upload.
    /// - Parameters:
    ///   - ipaPath: Path to the IPA file.
    ///   - appId: The App Store Connect app ID.
    ///   - progress: Callback for progress updates.
    /// - Returns: The build upload ID.
    public func upload(
        ipaPath: String,
        appId: String,
        progress: @escaping @Sendable (UploadProgress) -> Void
    ) async throws -> String {
        // Validate file exists
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: ipaPath, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            throw TestFlightError.ipaNotFound(ipaPath)
        }

        // Get file size
        let attributes = try fileManager.attributesOfItem(atPath: ipaPath)
        guard let fileSize = attributes[.size] as? Int64 else {
            throw TestFlightError.invalidIPA("Could not determine file size")
        }

        logger.info("Starting upload of \(ipaPath) (\(formatBytes(fileSize)))")

        // Create build upload session
        let buildUpload = try await api.createBuildUpload(appId: appId)
        logger.info("Created build upload session: \(buildUpload.id)")

        // Calculate chunks
        let chunks = calculateChunks(fileSize: fileSize)
        logger.info("File will be uploaded in \(chunks.count) chunks")

        // Open file for reading
        let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: ipaPath))
        defer { try? fileHandle.close() }

        // Upload each chunk
        var bytesUploaded: Int64 = 0

        for (index, chunk) in chunks.enumerated() {
            // Read chunk data
            try fileHandle.seek(toOffset: UInt64(chunk.offset))
            guard let data = try fileHandle.read(upToCount: Int(chunk.size)) else {
                throw TestFlightError.chunkUploadFailed(chunkIndex: index, reason: "Failed to read chunk data")
            }

            // Calculate checksum
            let checksum = calculateMD5(data: data)
            let chunkInfo = ChunkInfo(
                index: index,
                offset: chunk.offset,
                size: chunk.size,
                totalSize: fileSize,
                checksum: checksum
            )

            // Reserve upload file slot
            let reservation = try await api.reserveBuildUploadFile(
                buildUploadId: buildUpload.id,
                chunk: chunkInfo
            )

            // Upload chunk to S3 with retries
            try await uploadChunkWithRetry(
                data: data,
                uploadUrl: reservation.uploadUrl,
                checksum: checksum,
                chunkIndex: index
            )

            // Commit the uploaded chunk
            try await api.commitBuildUploadFile(fileId: reservation.fileId)

            bytesUploaded += chunk.size

            // Report progress
            progress(UploadProgress(
                bytesUploaded: bytesUploaded,
                totalBytes: fileSize,
                currentChunk: index + 1,
                totalChunks: chunks.count
            ))

            logger.debug("Uploaded chunk \(index + 1)/\(chunks.count)")
        }

        // Complete the upload
        try await api.completeBuildUpload(buildUploadId: buildUpload.id)
        logger.info("Upload completed successfully")

        return buildUpload.id
    }

    // MARK: - Private Methods

    private struct ChunkRange: Sendable {
        let offset: Int64
        let size: Int64
    }

    private func calculateChunks(fileSize: Int64) -> [ChunkRange] {
        var chunks: [ChunkRange] = []
        var offset: Int64 = 0

        while offset < fileSize {
            let remaining = fileSize - offset
            let size = min(Int64(chunkSize), remaining)
            chunks.append(ChunkRange(offset: offset, size: size))
            offset += size
        }

        return chunks
    }

    private func calculateMD5(data: Data) -> String {
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func uploadChunkWithRetry(
        data: Data,
        uploadUrl: String,
        checksum: String,
        chunkIndex: Int
    ) async throws {
        var lastError: Error?

        for attempt in 0 ..< Self.maxRetries {
            do {
                try await uploadChunk(data: data, uploadUrl: uploadUrl, checksum: checksum)
                return
            } catch {
                lastError = error
                logger.warning("Chunk \(chunkIndex) upload attempt \(attempt + 1) failed: \(error)")

                if attempt < Self.maxRetries - 1 {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw TestFlightError.chunkUploadFailed(
            chunkIndex: chunkIndex,
            reason: lastError?.localizedDescription ?? "Unknown error"
        )
    }

    private func uploadChunk(
        data: Data,
        uploadUrl: String,
        checksum: String
    ) async throws {
        var request = HTTPClientRequest(url: uploadUrl)
        request.method = .PUT
        request.headers.add(name: "Content-Type", value: "application/octet-stream")
        request.headers.add(name: "Content-MD5", value: Data(checksum.utf8).base64EncodedString())
        request.headers.add(name: "Content-Length", value: "\(data.count)")
        request.body = .bytes(ByteBuffer(bytes: data))

        let response = try await httpClient.execute(request, timeout: .seconds(300))

        guard response.status == .ok || response.status == .noContent else {
            let bodyBytes = try await response.body.collect(upTo: 1024 * 1024)
            let bodyString = String(buffer: bodyBytes)
            throw TestFlightError.chunkUploadFailed(
                chunkIndex: 0,
                reason: "HTTP \(response.status.code): \(bodyString)"
            )
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
