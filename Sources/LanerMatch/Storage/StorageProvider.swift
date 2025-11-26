import Foundation

/// Protocol for providing storage backend for certificates and provisioning profiles.
///
/// Implementations should provide secure storage with support for:
/// - Downloading existing certificates/profiles from storage
/// - Uploading new certificates/profiles to storage
/// - Checking if storage exists
public protocol StorageProvider: Sendable {
    /// Downloads the repository contents to a local path.
    ///
    /// - Parameter localPath: The local directory path where the storage should be downloaded.
    /// - Throws: `MatchError` if the download operation fails.
    func download(to localPath: URL) async throws

    /// Uploads local changes back to the storage.
    ///
    /// - Parameters:
    ///   - localPath: The local directory path containing the changes to upload.
    ///   - message: A commit message describing the changes.
    /// - Throws: `MatchError` if the upload operation fails.
    func upload(from localPath: URL, message: String) async throws

    /// Checks if the storage exists.
    ///
    /// - Returns: `true` if the storage exists, `false` otherwise.
    /// - Throws: `MatchError` if the check operation fails.
    func exists() async throws -> Bool
}
