import Crypto
import Foundation
import LanerKit

/// Represents a cached compiled manifest.
public struct CachedManifest: Sendable, Codable {
    /// The path to the compiled executable.
    public let executablePath: URL

    /// SHA256 hash of the source files.
    public let sourceHash: String

    /// Timestamp when the manifest was compiled.
    public let compiledAt: Date

    public init(executablePath: URL, sourceHash: String, compiledAt: Date) {
        self.executablePath = executablePath
        self.sourceHash = sourceHash
        self.compiledAt = compiledAt
    }
}

/// Caches compiled manifests to avoid unnecessary recompilation.
///
/// The cache uses a two-level hashing strategy:
/// 1. Project hash: SHA256 of the absolute manifest path
/// 2. Source hash: SHA256 of all manifest source files
///
/// Cache directory structure:
/// ```
/// ~/.laner/cache/
/// ├── <project-hash-1>/
/// │   ├── manifest.json         # CachedManifest metadata
/// │   └── LanerManifest     # Compiled executable
/// ├── <project-hash-2>/
/// │   ├── manifest.json
/// │   └── LanerManifest
/// └── ...
/// ```
public struct ManifestCache: Sendable {
    /// The root cache directory (default: ~/.laner/cache/)
    public let cacheDirectory: URL

    /// Name of the compiled executable file
    private let executableName = "LanerManifest"

    /// Name of the metadata file
    private let metadataFileName = "manifest.json"

    /// Creates a new manifest cache.
    /// - Parameter cacheDirectory: Custom cache directory. Defaults to ~/.laner/cache/
    public init(cacheDirectory: URL? = nil) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            self.cacheDirectory = homeDirectory
                .appendingPathComponent(".laner", isDirectory: true)
                .appendingPathComponent("cache", isDirectory: true)
        }
    }

    /// Gets a cached manifest if it exists and the source hasn't changed.
    /// - Parameter manifestPath: Absolute path to the Lanerfile.swift
    /// - Returns: Cached manifest if valid, nil if recompilation needed
    /// - Throws: I/O errors or hash computation errors
    public func get(for manifestPath: URL) throws -> CachedManifest? {
        let fileManager = FileManager.default
        let projectHash = try computeProjectHash(for: manifestPath)
        let projectCacheDir = cacheDirectory.appendingPathComponent(projectHash, isDirectory: true)

        // Check if cache directory exists
        guard fileManager.directoryExists(atPath: projectCacheDir.path(percentEncoded: false)) else {
            return nil
        }

        // Load metadata
        let metadataPath = projectCacheDir.appendingPathComponent(metadataFileName)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: metadataPath.path(percentEncoded: false), isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            return nil
        }

        let metadataData = try Data(contentsOf: metadataPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let cachedManifest = try decoder.decode(CachedManifest.self, from: metadataData)

        // Verify executable exists
        var execIsDirectory: ObjCBool = false
        guard fileManager.fileExists(
            atPath: cachedManifest.executablePath.path(percentEncoded: false),
            isDirectory: &execIsDirectory
        ),
            !execIsDirectory.boolValue
        else {
            return nil
        }

        // Compute current source hash
        let currentHash = try computeHash(for: manifestPath)

        // Compare hashes
        if currentHash == cachedManifest.sourceHash {
            return cachedManifest
        }

        // Source has changed, cache is invalid
        return nil
    }

    /// Stores a compiled manifest in the cache.
    /// - Parameters:
    ///   - manifest: The cached manifest to store
    ///   - path: The manifest source path
    /// - Throws: I/O errors or encoding errors
    public func store(_ manifest: CachedManifest, for path: URL) throws {
        let fileManager = FileManager.default
        let projectHash = try computeProjectHash(for: path)
        let projectCacheDir = cacheDirectory.appendingPathComponent(projectHash, isDirectory: true)

        // Create cache directory if needed
        try fileManager.createDirectoryIfNeeded(atPath: projectCacheDir.path(percentEncoded: false))

        // Save metadata
        let metadataPath = projectCacheDir.appendingPathComponent(metadataFileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadataData = try encoder.encode(manifest)
        try metadataData.write(to: metadataPath)
    }

    /// Invalidates the cache for a manifest by removing its cache directory.
    /// - Parameter path: The manifest source path
    /// - Throws: I/O errors or hash computation errors
    public func invalidate(for path: URL) throws {
        let fileManager = FileManager.default
        let projectHash = try computeProjectHash(for: path)
        let projectCacheDir = cacheDirectory.appendingPathComponent(projectHash, isDirectory: true)

        if fileManager.directoryExists(atPath: projectCacheDir.path(percentEncoded: false)) {
            try fileManager.removeItem(at: projectCacheDir)
        }
    }

    /// Computes SHA256 hash of all manifest source files.
    ///
    /// The hash includes:
    /// - Content of Lanerfile.swift
    /// - Content of all .swift files in LanerHelpers/ (if directory exists)
    ///
    /// - Parameter manifestPath: Absolute path to the Lanerfile.swift
    /// - Returns: Hex-encoded SHA256 hash
    /// - Throws: I/O errors if files cannot be read
    public func computeHash(for manifestPath: URL) throws -> String {
        let fileManager = FileManager.default
        var hasher = SHA256()

        // Hash the main manifest file
        let manifestData = try Data(contentsOf: manifestPath)
        hasher.update(data: manifestData)

        // Check for LanerHelpers directory
        let manifestDir = manifestPath.deletingLastPathComponent()
        let helpersDir = manifestDir.appendingPathComponent("LanerHelpers", isDirectory: true)

        if fileManager.directoryExists(atPath: helpersDir.path(percentEncoded: false)) {
            // Get all .swift files in helpers directory (recursively)
            let helperFiles = try collectSwiftFiles(in: helpersDir)

            // Sort files for consistent hashing
            let sortedFiles = helperFiles.sorted { $0.path < $1.path }

            for file in sortedFiles {
                let fileData = try Data(contentsOf: file)
                hasher.update(data: fileData)
            }
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Computes a project hash based on the absolute manifest path.
    /// - Parameter manifestPath: Absolute path to the manifest
    /// - Returns: Hex-encoded SHA256 hash of the path
    private func computeProjectHash(for manifestPath: URL) throws -> String {
        let absolutePath = manifestPath.path(percentEncoded: false)
        guard let pathData = absolutePath.data(using: .utf8) else {
            throw ManifestCacheError.invalidPath(absolutePath)
        }

        let digest = SHA256.hash(data: pathData)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Recursively collects all .swift files in a directory.
    /// - Parameter directory: The directory to search
    /// - Returns: Array of file URLs
    /// - Throws: I/O errors
    private func collectSwiftFiles(in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        var swiftFiles: [URL] = []

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues.isRegularFile == true, fileURL.pathExtension == "swift" {
                swiftFiles.append(fileURL)
            }
        }

        return swiftFiles
    }

    /// Returns the path where a compiled executable should be stored.
    /// - Parameter manifestPath: The manifest source path
    /// - Returns: URL for the executable in the cache
    /// - Throws: Hash computation errors
    public func executablePath(for manifestPath: URL) throws -> URL {
        let projectHash = try computeProjectHash(for: manifestPath)
        let projectCacheDir = cacheDirectory.appendingPathComponent(projectHash, isDirectory: true)
        return projectCacheDir.appendingPathComponent(executableName)
    }
}

/// Errors that can occur during manifest caching operations.
public enum ManifestCacheError: Error, LocalizedError {
    /// The manifest path is invalid or cannot be encoded.
    case invalidPath(String)

    /// Failed to compute hash for source files.
    case hashComputationFailed(String)

    /// Cache is corrupted or in an invalid state.
    case cacheCorrupted(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidPath(path):
            "Invalid manifest path: \(path)"
        case let .hashComputationFailed(reason):
            "Failed to compute source hash: \(reason)"
        case let .cacheCorrupted(reason):
            "Cache is corrupted: \(reason)"
        }
    }
}
