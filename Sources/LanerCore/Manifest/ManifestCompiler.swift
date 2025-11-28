import Foundation
import LanerDSL
import LanerKit

/// An actor that compiles Swift manifest files into executable binaries.
///
/// `ManifestCompiler` follows a Tuist-style compilation strategy:
/// 1. Creates a temporary directory for compilation
/// 2. Generates a Package.swift that depends on LanerDSL
/// 3. Copies the user's Lanerfile.swift and any helpers
/// 4. Adds a main.swift wrapper that imports user code and outputs JSON
/// 5. Runs `swift build` to compile the manifest
/// 6. Executes the compiled binary to get JSON output
/// 7. Parses the JSON into a `Lanerfile` instance
///
/// ## Example
/// ```swift
/// let compiler = ManifestCompiler()
/// let manifestPath = URL(fileURLWithPath: "/path/to/project/Laner/Lanerfile.swift")
/// let lanerfile = try await compiler.compile(at: manifestPath)
/// ```
public actor ManifestCompiler {
    /// The shell executor used for running commands.
    private let shell: ShellExecutor

    /// The file manager used for file operations.
    private let fileManager: FileManager

    /// Creates a new manifest compiler.
    /// - Parameters:
    ///   - shell: The shell executor to use. Defaults to `.shared`.
    ///   - fileManager: The file manager to use. Defaults to `.default`.
    public init(
        shell: ShellExecutor = .shared,
        fileManager: FileManager = .default
    ) {
        self.shell = shell
        self.fileManager = fileManager
    }

    /// Compiles a Lanerfile.swift and returns the configuration.
    ///
    /// This method creates a temporary Swift package, compiles the manifest,
    /// executes it to produce JSON output, and parses that into a `Lanerfile`.
    ///
    /// - Parameter path: The path to the Lanerfile.swift file.
    /// - Returns: The compiled and parsed `Lanerfile` configuration.
    /// - Throws: `ManifestError` if the manifest is not found, compilation fails,
    ///           execution fails, or JSON parsing fails.
    public func compile(at path: URL) async throws -> Lanerfile {
        // Check that the manifest exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw ManifestError.notFound(path: path)
        }

        // Get the Laner installation path for dependency resolution
        let installPath = try lanerInstallPath()

        // Create a temporary directory for compilation
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("laner-manifest-\(UUID().uuidString)")

        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            // Clean up temporary directory
            try? fileManager.removeItem(at: tempDir)
        }

        // Set up the package structure
        let sourcesDir = tempDir.appendingPathComponent("Sources")
        try fileManager.createDirectory(at: sourcesDir, withIntermediateDirectories: true)

        // Copy the user's Lanerfile.swift
        let manifestDestination = sourcesDir.appendingPathComponent("Lanerfile.swift")
        try fileManager.copyItem(at: path, to: manifestDestination)

        // Copy LanerHelpers if it exists
        let helpersDir = path.deletingLastPathComponent().appendingPathComponent("LanerHelpers")
        if fileManager.directoryExists(atPath: helpersDir.path) {
            let helpersDestination = sourcesDir.appendingPathComponent("LanerHelpers")
            try fileManager.copyItem(at: helpersDir, to: helpersDestination)
        }

        // Generate Package.swift
        let packageSwift = generatePackageSwift(installPath: installPath)
        let packagePath = tempDir.appendingPathComponent("Package.swift")
        try packageSwift.write(to: packagePath, atomically: true, encoding: .utf8)

        // Generate main.swift wrapper
        let mainSwift = generateMainSwift()
        let mainPath = sourcesDir.appendingPathComponent("main.swift")
        try mainSwift.write(to: mainPath, atomically: true, encoding: .utf8)

        // Compile the manifest
        let buildResult = try await shell.run(
            "swift",
            arguments: ["build", "-c", "release"],
            workingDirectory: tempDir,
            timeout: .seconds(120)
        )

        guard buildResult.isSuccess else {
            throw ManifestError.compilationFailed(output: buildResult.combinedOutput)
        }

        // Find the executable path
        let executablePath = tempDir
            .appendingPathComponent(".build/release/LanerManifest")

        // Execute the manifest to get JSON output
        let execResult = try await shell.run(
            executablePath.path,
            workingDirectory: tempDir,
            timeout: .seconds(30)
        )

        guard execResult.isSuccess else {
            throw ManifestError.executionFailed(output: execResult.combinedOutput)
        }

        // Parse the JSON output
        guard let jsonData = execResult.stdout.data(using: .utf8) else {
            throw ManifestError.invalidOutput(details: "Could not convert output to UTF-8 data")
        }

        do {
            let decoder = JSONDecoder()
            let lanerfile = try decoder.decode(Lanerfile.self, from: jsonData)
            return lanerfile
        } catch {
            throw ManifestError.invalidOutput(details: error.localizedDescription)
        }
    }

    /// Gets the Laner installation path for dependency resolution.
    ///
    /// This method determines where the Laner package is installed by checking multiple locations:
    /// 1. Bundled installation: `<install>/bin/laner` with sources at `<install>/lib/laner/`
    /// 2. Development build: `<package-root>/.build/release/laner`
    /// 3. Current directory: For local development
    ///
    /// The path is used to reference LanerDSL in the generated Package.swift.
    ///
    /// - Returns: The URL to the Laner package root directory (containing Package.swift and Sources/).
    /// - Throws: `ManifestError.installPathNotFound` if the path cannot be determined,
    ///           or `ManifestError.versionMismatch` if bundled version doesn't match binary.
    public func lanerInstallPath() throws -> URL {
        // Try multiple strategies to find the laner installation

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

        // Strategy 1: Find via PATH
        if let pathExecutable = fileManager.findExecutable("laner") {
            executablePaths.append(pathExecutable)
        }

        // Try each executable path
        for executablePath in executablePaths {
            let executableURL = URL(fileURLWithPath: executablePath)
            let resolvedURL = resolveSymlinks(executableURL)

            // Check for bundled installation
            // Structure: <install>/bin/laner with sources at <install>/lib/laner/
            let binDir = resolvedURL.deletingLastPathComponent()
            let installDir = binDir.deletingLastPathComponent()
            let libPath = installDir.appendingPathComponent("lib/laner")
            let bundledPackage = libPath.appendingPathComponent("Package.swift")

            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: bundledPackage.path, isDirectory: &isDir), !isDir.boolValue {
                // Validate version matches
                try validateBundledVersion(at: installDir)
                return libPath
            }

            // Check for development build
            // Expected structure: <package-root>/.build/release/laner
            // So we go up 3 levels: ../../..
            let packageRoot = resolvedURL
                .deletingLastPathComponent() // .build/release
                .deletingLastPathComponent() // .build
                .deletingLastPathComponent() // package root

            let devPackage = packageRoot.appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: devPackage.path, isDirectory: &isDir), !isDir.boolValue {
                return packageRoot
            }
        }

        // Strategy 2: Current directory (development mode)
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let packageSwiftPath = currentDir.appendingPathComponent("Package.swift")
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: packageSwiftPath.path, isDirectory: &isDir), !isDir.boolValue {
            return currentDir
        }

        throw ManifestError.installPathNotFound
    }

    /// Resolves symlinks to get the actual file location.
    /// - Parameter url: The URL that may be a symlink.
    /// - Returns: The resolved URL, or the original URL if not a symlink.
    private func resolveSymlinks(_ url: URL) -> URL {
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

    /// Validates that the bundled DSL version matches the binary version.
    /// - Parameter installDir: The installation directory containing the VERSION file.
    /// - Throws: `ManifestError.versionMismatch` if versions don't match.
    private func validateBundledVersion(at installDir: URL) throws {
        let versionFile = installDir.appendingPathComponent("VERSION")

        guard let bundledVersion = try? String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            // No VERSION file found - skip validation for backwards compatibility
            return
        }

        guard bundledVersion == lanerVersion else {
            throw ManifestError.versionMismatch(expected: lanerVersion, found: bundledVersion)
        }
    }

    // MARK: - Code Generation

    /// Generates the Package.swift manifest for compiling the user's manifest.
    ///
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
    ///
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
}
