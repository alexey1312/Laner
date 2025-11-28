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
/// 2. Check cache for existing compiled manifest
/// 3. If cache miss, compile the Swift file into an executable
/// 4. Execute the compiled manifest
/// 5. Parse the JSON output into a `Lanerfile`
///
/// ## Caching
///
/// Compiled manifests are cached in `~/.laner/cache/<project-hash>/` to avoid
/// recompilation. The cache is invalidated when source files change.
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

    /// The manifest cache for storing compiled manifests.
    private let cache: ManifestCache

    /// Creates a new manifest loader.
    /// - Parameters:
    ///   - shell: The shell executor to use. Defaults to shared executor.
    ///   - logger: The logger for diagnostic output. Defaults to manifest category.
    ///   - cache: The manifest cache. Defaults to standard cache location.
    public init(
        shell: ShellExecutor = .shared,
        logger: Logger = Logger.laner(.manifest),
        cache: ManifestCache = ManifestCache()
    ) {
        self.shell = shell
        self.logger = logger
        self.cache = cache
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
    /// 2. Checks cache for existing compiled manifest
    /// 3. If cache miss, compiles it into an executable
    /// 4. Executes the compiled manifest
    /// 5. Parses the output into a `Lanerfile`
    ///
    /// - Parameter directory: The project directory containing the manifest.
    /// - Returns: The loaded `Lanerfile` configuration.
    /// - Throws: `ManifestError` if loading fails at any stage.
    public func load(from directory: URL) async throws -> Lanerfile {
        logger.info("Loading manifest from: \(directory.path)")

        // Find manifest path
        let manifestPath = try findManifestPath(in: directory)
        logger.debug("Found manifest at: \(manifestPath.path)")

        // Check cache first
        let executablePath: URL
        if let cached = try? cache.get(for: manifestPath) {
            logger.debug("Using cached manifest from: \(cached.executablePath.path)")
            executablePath = cached.executablePath
        } else {
            // Compile the manifest
            logger.debug("Cache miss, compiling manifest...")
            let compiledPath = try await compile(manifest: manifestPath)
            logger.debug("Compiled manifest to: \(compiledPath.path)")

            // Store in cache - the executable is at .build/release/LanerManifest
            let sourceHash = try cache.computeHash(for: manifestPath)
            let cachedManifest = CachedManifest(
                executablePath: compiledPath,
                sourceHash: sourceHash,
                compiledAt: Date()
            )
            try cache.store(cachedManifest, for: manifestPath)
            executablePath = compiledPath
        }

        // Execute and parse
        let lanerfile = try await execute(manifest: executablePath)
        logger.info("Successfully loaded manifest with \(lanerfile.lanes.count) lane(s)")

        return lanerfile
    }

    // MARK: - Private Methods

    /// Compiles a manifest file into an executable.
    ///
    /// This method creates a Swift package in the cache directory that depends on LanerDSL,
    /// copies the user's Lanerfile.swift into it, and runs `swift build` to compile.
    /// The cache directory is reused to preserve `.build/` artifacts for faster rebuilds.
    ///
    /// - Parameter manifest: The manifest file to compile.
    /// - Returns: The URL of the compiled executable.
    /// - Throws: `ManifestError.compilationFailed` if compilation fails.
    private func compile(manifest: URL) async throws -> URL {
        // Determine Laner installation path for linking
        guard let installPath = try await determineInstallPath() else {
            throw ManifestError.installPathNotFound
        }

        let fileManager = FileManager.default

        // Use cache directory instead of temp to preserve .build/ between runs
        let buildDir = try cache.executablePath(for: manifest).deletingLastPathComponent()

        try fileManager.createDirectory(
            at: buildDir,
            withIntermediateDirectories: true
        )

        // Set up the package structure
        let sourcesDir = buildDir.appendingPathComponent("Sources")

        // Clean Sources directory to ensure fresh copy of user files
        var sourcesDirIsDir: ObjCBool = false
        if fileManager.fileExists(atPath: sourcesDir.path, isDirectory: &sourcesDirIsDir) {
            try fileManager.removeItem(at: sourcesDir)
        }
        try fileManager.createDirectory(at: sourcesDir, withIntermediateDirectories: true)

        // Copy the user's Lanerfile.swift
        let manifestDestination = sourcesDir.appendingPathComponent("Lanerfile.swift")
        try fileManager.copyItem(at: manifest, to: manifestDestination)

        // Copy LanerHelpers if it exists
        let helpersDir = manifest.deletingLastPathComponent().appendingPathComponent("LanerHelpers")
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: helpersDir.path, isDirectory: &isDir), isDir.boolValue {
            let helpersDestination = sourcesDir.appendingPathComponent("LanerHelpers")
            try fileManager.copyItem(at: helpersDir, to: helpersDestination)
        }

        // Generate Package.swift (always regenerate to ensure correct install path)
        let packageSwift = generatePackageSwift(installPath: installPath)
        let packagePath = buildDir.appendingPathComponent("Package.swift")
        try packageSwift.write(to: packagePath, atomically: true, encoding: .utf8)

        // Generate main.swift wrapper
        let mainSwift = generateMainSwift()
        let mainPath = sourcesDir.appendingPathComponent("main.swift")
        try mainSwift.write(to: mainPath, atomically: true, encoding: .utf8)

        // Compile the manifest using swift build
        // First compilation may take longer due to dependency resolution
        logger.debug("Compiling manifest with install path: \(installPath.path)")
        let result = try await shell.run(
            "swift",
            arguments: ["build", "-c", "release"],
            workingDirectory: buildDir,
            timeout: .seconds(300)
        )

        // Check compilation result
        guard result.isSuccess else {
            throw ManifestError.compilationFailed(
                output: result.stderr.isEmpty ? result.stdout : result.stderr
            )
        }

        let executablePath = buildDir.appendingPathComponent(".build/release/LanerManifest")
        return executablePath
    }

    /// Generates the Package.swift manifest for compiling the user's manifest.
    /// - Parameter installPath: The path to the Laner package root.
    /// - Returns: The generated Package.swift content as a string.
    private func generatePackageSwift(installPath: URL) -> String {
        """
        // swift-tools-version:6.0
        import PackageDescription

        let package = Package(
            name: "LanerManifest",
            platforms: [.macOS(.v13)],
            dependencies: [
                .package(path: "\(installPath.path)")
            ],
            targets: [
                .executableTarget(
                    name: "LanerManifest",
                    dependencies: [
                        .product(name: "LanerDSL", package: "Laner")
                    ],
                    path: "Sources"
                )
            ]
        )
        """
    }

    /// Generates the main.swift wrapper that executes the user's manifest and outputs JSON.
    /// - Returns: The generated main.swift content as a string.
    private func generateMainSwift() -> String {
        """
        import Foundation
        import LanerDSL

        // The user's Lanerfile.swift is also included in Sources/
        // It should define a global variable named 'laner' of type Lanerfile

        // Output JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(laner)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        } catch {
            print("Error encoding manifest: \\(error)", to: &standardError)
            exit(1)
        }

        // Helper to print to stderr
        struct StandardError: TextOutputStream {
            mutating func write(_ string: String) {
                FileHandle.standardError.write(Data(string.utf8))
            }
        }

        var standardError = StandardError()
        """
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
    ///
    /// This method checks multiple locations to find Laner's DSL sources:
    /// 1. Bundled installation: `<install>/bin/laner` with sources at `<install>/lib/laner/`
    /// 2. Development build: `<package-root>/.build/release/laner`
    /// 3. Current directory: For local development
    ///
    /// - Returns: The installation path URL, or nil if not found.
    private func determineInstallPath() async throws -> URL? {
        let fileManager = FileManager.default

        // Get candidate executable paths
        var executablePaths: [String] = []

        // Strategy 0: Current executable path (most reliable for bundled installs)
        let currentExecutable = CommandLine.arguments[0]
        if currentExecutable.hasPrefix("/") {
            executablePaths.append(currentExecutable)
        } else {
            // Relative path - resolve against current directory
            let absolutePath = URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(currentExecutable).path
            executablePaths.append(absolutePath)
        }

        // Strategy 1: Find via PATH using `which`
        let result = try await shell.run("which", arguments: ["laner"])
        if result.isSuccess {
            let pathExecutable = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !pathExecutable.isEmpty {
                executablePaths.append(pathExecutable)
            }
        }

        // Try each executable path
        for executablePath in executablePaths {
            let executableURL = URL(fileURLWithPath: executablePath)
            let resolvedURL = resolveSymlinks(executableURL, fileManager: fileManager)

            // Check for bundled installation
            // Structure: <install>/bin/laner with sources at <install>/lib/laner/
            let binDir = resolvedURL.deletingLastPathComponent()
            let installDir = binDir.deletingLastPathComponent()
            let libPath = installDir.appendingPathComponent("lib/laner")
            let bundledPackage = libPath.appendingPathComponent("Package.swift")

            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: bundledPackage.path, isDirectory: &isDirectory),
               !isDirectory.boolValue {
                return libPath
            }

            // Check for development build
            // Expected structure: <package-root>/.build/release/laner
            let packageRoot = resolvedURL
                .deletingLastPathComponent() // .build/release
                .deletingLastPathComponent() // .build
                .deletingLastPathComponent() // package root

            let devPackage = packageRoot.appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: devPackage.path, isDirectory: &isDirectory),
               !isDirectory.boolValue {
                return packageRoot
            }
        }

        // Strategy 2: Current directory (development mode)
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let packageSwiftPath = currentDir.appendingPathComponent("Package.swift")
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: packageSwiftPath.path, isDirectory: &isDir),
           !isDir.boolValue {
            return currentDir
        }

        return nil
    }

    /// Resolves symlinks to get the actual file location.
    private func resolveSymlinks(_ url: URL, fileManager: FileManager) -> URL {
        do {
            let destination = try fileManager.destinationOfSymbolicLink(atPath: url.path)
            if destination.isEmpty {
                return url
            }
            // Handle relative symlinks
            if destination.hasPrefix("/") {
                return URL(fileURLWithPath: destination)
            } else {
                return url.deletingLastPathComponent().appendingPathComponent(destination)
            }
        } catch {
            return url
        }
    }
}
