import Foundation
import LanerDSL
import LanerKit
import Logging

/// Loads Lanerfile.pkl manifests using the Pkl evaluator.
///
/// `ManifestLoader` finds and evaluates Pkl configuration files,
/// producing typed `Lanerfile.Module` results in milliseconds.
///
/// ## Finding Manifests
///
/// The loader looks for manifests in a standard location:
/// ```
/// ProjectRoot/
/// └── Laner/
///     ├── Lanerfile.pkl
///     └── pkl/
///         └── Lanerfile.pkl (schema)
/// ```
///
/// ## Example Usage
///
/// ```swift
/// let loader = ManifestLoader()
/// let module = try await loader.load(from: projectDirectory)
/// print("Found \(module.lanes.count) lanes")
/// ```
public struct ManifestLoader: Sendable {
    /// The file name for the manifest.
    public static let manifestFileName = "Lanerfile.pkl"

    /// The directory name containing the manifest.
    private static let manifestDirectoryName = "Laner"

    /// The logger for diagnostic output.
    private let logger: Logging.Logger

    /// Creates a new manifest loader.
    /// - Parameter logger: The logger for diagnostic output. Defaults to manifest category.
    public init(
        logger: Logging.Logger = Logging.Logger.laner(.manifest)
    ) {
        self.logger = logger
    }

    /// Checks if a manifest exists in the directory.
    /// - Parameter directory: The project directory to check.
    /// - Returns: `true` if a Lanerfile.pkl exists at the expected location.
    public func manifestExists(in directory: URL) -> Bool {
        do {
            let manifestPath = try findManifestPath(in: directory)
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: manifestPath.path, isDirectory: &isDirectory)
                && !isDirectory.boolValue
        } catch {
            return false
        }
    }

    /// Finds the manifest file path in a directory.
    /// - Parameter directory: The project directory to search.
    /// - Returns: The URL of the manifest file.
    /// - Throws: `ManifestError.notFound` if the manifest doesn't exist.
    public func findManifestPath(in directory: URL) throws -> URL {
        let manifestURL = directory
            .appendingPathComponent(Self.manifestDirectoryName)
            .appendingPathComponent(Self.manifestFileName)

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: manifestURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            throw ManifestError.notFound(path: manifestURL)
        }

        return manifestURL
    }

    /// Loads a manifest from a directory.
    ///
    /// This method evaluates the Pkl manifest using the embedded Pkl evaluator.
    /// No compilation step is needed — evaluation is near-instant.
    ///
    /// - Parameter directory: The project directory containing the manifest.
    /// - Returns: The evaluated `Lanerfile.Module` configuration.
    /// - Throws: `ManifestError` if loading fails.
    public func load(from directory: URL) async throws -> Lanerfile.Module {
        logger.info("Loading manifest from: \(directory.path)")

        let manifestPath = try findManifestPath(in: directory)
        logger.debug("Found manifest at: \(manifestPath.path)")

        do {
            let module = try await Lanerfile.loadFrom(source: .path(manifestPath.path))
            logger.info("Successfully loaded manifest with \(module.lanes.count) lane(s)")
            return module
        } catch {
            throw ManifestError.evaluationFailed(
                details: String(describing: error)
            )
        }
    }
}
