import Foundation
import LanerKit
import LanerDSL
import Logging

/// Loads and manages Lanerfile manifests.
///
/// `ManifestLoader` is responsible for finding, compiling, and executing
/// Lanerfile.swift files. It handles the manifest lifecycle from
/// discovery to loaded configuration.
///
/// ## Finding Manifests
///
/// The loader looks for manifests in a standard location:
/// ```
/// ProjectRoot/
/// └── Laner/
///     └── Lanerfile.swift
/// ```
///
/// ## Loading Process
///
/// 1. Find the manifest file path
/// 2. Compile the Swift file into an executable
/// 3. Execute the compiled manifest
/// 4. Parse the JSON output into a `Lanerfile`
///
/// ## Example Usage
///
/// ```swift
/// let loader = ManifestLoader()
///
/// // Check if manifest exists
/// if loader.manifestExists(in: projectDirectory) {
///     let manifest = try await loader.load(from: projectDirectory)
///     print("Found \(manifest.lanes.count) lanes")
/// }
/// ```
public struct ManifestLoader: Sendable {
    /// The file name for the manifest.
    private static let manifestFileName = "Lanerfile.swift"

    /// The directory name containing the manifest.
    private static let manifestDirectoryName = "Laner"

    /// The shell executor used for compilation and execution.
    private let shell: ShellExecutor

    /// The logger for diagnostic output.
    private let logger: Logger

    /// Creates a new manifest loader.
    /// - Parameters:
    ///   - shell: The shell executor to use. Defaults to shared executor.
    ///   - logger: The logger for diagnostic output. Defaults to manifest category.
    public init(
        shell: ShellExecutor = .shared,
        logger: Logger = Logger.laner(.manifest)
    ) {
        self.shell = shell
        self.logger = logger
    }

    /// Checks if a manifest exists in the directory.
    /// - Parameter directory: The project directory to check.
    /// - Returns: `true` if a manifest exists at the expected location.
    public func manifestExists(in directory: URL) -> Bool {
        do {
            let manifestPath = try findManifestPath(in: directory)
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: manifestPath.path, isDirectory: &isDirectory) && !isDirectory.boolValue
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
              !isDirectory.boolValue else {
            throw ManifestError.notFound(path: manifestURL)
        }

        return manifestURL
    }

    /// Loads a manifest from a directory.
    ///
    /// This method performs the complete manifest loading process:
    /// 1. Finds the manifest file
    /// 2. Compiles it into an executable
    /// 3. Executes the compiled manifest
    /// 4. Parses the output into a `Lanerfile`
    ///
    /// - Parameter directory: The project directory containing the manifest.
    /// - Returns: The loaded `Lanerfile` configuration.
    /// - Throws: `ManifestError` if loading fails at any stage.
    public func load(from directory: URL) async throws -> Lanerfile {
        logger.info("Loading manifest from: \(directory.path)")

        // Find manifest path
        let manifestPath = try findManifestPath(in: directory)
        logger.debug("Found manifest at: \(manifestPath.path)")

        // Compile the manifest
        let executablePath = try await compile(manifest: manifestPath)
        logger.debug("Compiled manifest to: \(executablePath.path)")

        // Execute and parse
        let lanerfile = try await execute(manifest: executablePath)
        logger.info("Successfully loaded manifest with \(lanerfile.lanes.count) lane(s)")

        return lanerfile
    }

    // MARK: - Private Methods

    /// Compiles a manifest file into an executable.
    /// - Parameter manifest: The manifest file to compile.
    /// - Returns: The URL of the compiled executable.
    /// - Throws: `ManifestError.compilationFailed` if compilation fails.
    private func compile(manifest: URL) async throws -> URL {
        // Determine Laner installation path for linking
        guard let installPath = try await determineInstallPath() else {
            throw ManifestError.installPathNotFound
        }

        // Create a temporary directory for the build
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("laner-manifest-\(UUID().uuidString)")

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        let executablePath = tempDir.appendingPathComponent("manifest")

        // Compile the manifest
        // Link against LanerDSL from the installation
        let result = try await shell.run(
            "swiftc",
            arguments: [
                manifest.path,
                "-o", executablePath.path,
                "-I", installPath.appendingPathComponent("include").path,
                "-L", installPath.appendingPathComponent("lib").path,
                "-lLanerDSL",
                "-parse-as-library",
                "-suppress-warnings"
            ],
            timeout: .seconds(60)
        )

        // Check compilation result
        guard result.isSuccess else {
            throw ManifestError.compilationFailed(
                output: result.stderr.isEmpty ? result.stdout : result.stderr
            )
        }

        return executablePath
    }

    /// Executes a compiled manifest and parses its output.
    /// - Parameter manifest: The compiled executable to run.
    /// - Returns: The parsed `Lanerfile`.
    /// - Throws: `ManifestError.executionFailed` or `ManifestError.invalidOutput`.
    private func execute(manifest: URL) async throws -> Lanerfile {
        let result = try await shell.run(
            manifest.path,
            arguments: [],
            timeout: .seconds(10)
        )

        guard result.isSuccess else {
            throw ManifestError.executionFailed(
                output: result.stderr.isEmpty ? result.stdout : result.stderr
            )
        }

        // Parse JSON output
        let jsonOutput = result.stdout
        guard let jsonData = jsonOutput.data(using: .utf8) else {
            throw ManifestError.invalidOutput(details: "Output is not valid UTF-8")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(Lanerfile.self, from: jsonData)
        } catch {
            throw ManifestError.invalidOutput(
                details: "Failed to decode JSON: \(error.localizedDescription)"
            )
        }
    }

    /// Determines the Laner installation path.
    /// - Returns: The installation path URL, or nil if not found.
    private func determineInstallPath() async throws -> URL? {
        // Try to find laner executable in PATH
        let result = try await shell.run(
            "which",
            arguments: ["laner"]
        )

        guard result.isSuccess else {
            return nil
        }

        let executablePath = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !executablePath.isEmpty else {
            return nil
        }

        // Resolve symlinks
        let resolvedPath: String
        if let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: executablePath) {
            resolvedPath = resolved
        } else {
            resolvedPath = executablePath
        }

        // Get the parent directory (bin) and then its parent (install root)
        let url = URL(fileURLWithPath: resolvedPath)
            .deletingLastPathComponent() // Remove executable name
            .deletingLastPathComponent() // Remove "bin" directory

        return url
    }
}
