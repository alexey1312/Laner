import Crypto
import Foundation
import LanerKit
import Logging

/// Caches manifest source hashes to detect when re-evaluation is needed.
///
/// The cache computes SHA256 of Pkl source files so the loader can
/// skip evaluation when the manifest hasn't changed.
public struct ManifestCache: Sendable {
    /// The logger for diagnostic output.
    private let logger: Logger

    /// The root cache directory (default: ~/.laner/cache/)
    public let cacheDirectory: URL

    /// Creates a new manifest cache.
    /// - Parameters:
    ///   - cacheDirectory: Custom cache directory. Defaults to ~/.laner/cache/
    ///   - logger: The logger for diagnostic output. Defaults to manifest category.
    public init(
        cacheDirectory: URL? = nil,
        logger: Logger = Logger.laner(.manifest)
    ) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            self.cacheDirectory = homeDirectory
                .appendingPathComponent(".laner", isDirectory: true)
                .appendingPathComponent("cache", isDirectory: true)
        }
        self.logger = logger
    }

    /// Checks whether the manifest source has changed since last evaluation.
    /// - Parameters:
    ///   - manifestPath: Path to the Lanerfile.pkl
    ///   - previousHash: The previously stored hash
    /// - Returns: `true` if the source has changed or no previous hash exists
    public func hasChanged(manifestPath: URL, previousHash: String?) -> Bool {
        guard let previousHash else { return true }
        do {
            let currentHash = try computeHash(for: manifestPath)
            return currentHash != previousHash
        } catch {
            logger.warning("Failed to compute manifest hash: \(error). Treating as changed.")
            return true
        }
    }

    /// Computes SHA256 hash of the manifest source file.
    ///
    /// - Parameter manifestPath: Absolute path to the Lanerfile.pkl
    /// - Returns: Hex-encoded SHA256 hash
    /// - Throws: I/O errors if files cannot be read
    public func computeHash(for manifestPath: URL) throws -> String {
        var hasher = SHA256()

        let manifestData = try Data(contentsOf: manifestPath)
        hasher.update(data: manifestData)

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
