import Foundation
import SwiftlaneDSL
import SwiftlaneKit

/// An actor that compiles Swift manifest files into executable binaries.
///
/// `ManifestCompiler` follows a Tuist-style compilation strategy:
/// 1. Creates a temporary directory for compilation
/// 2. Generates a Package.swift that depends on SwiftlaneDSL
/// 3. Copies the user's Swiftlanefile.swift and any helpers
/// 4. Adds a main.swift wrapper that imports user code and outputs JSON
/// 5. Runs `swift build` to compile the manifest
/// 6. Executes the compiled binary to get JSON output
/// 7. Parses the JSON into a `Swiftlanefile` instance
///
/// ## Example
/// ```swift
/// let compiler = ManifestCompiler()
/// let manifestPath = URL(fileURLWithPath: "/path/to/project/Swiftlane/Swiftlanefile.swift")
/// let swiftlanefile = try await compiler.compile(at: manifestPath)
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

    /// Compiles a Swiftlanefile.swift and returns the configuration.
    ///
    /// This method creates a temporary Swift package, compiles the manifest,
    /// executes it to produce JSON output, and parses that into a `Swiftlanefile`.
    ///
    /// - Parameter path: The path to the Swiftlanefile.swift file.
    /// - Returns: The compiled and parsed `Swiftlanefile` configuration.
    /// - Throws: `ManifestError` if the manifest is not found, compilation fails,
    ///           execution fails, or JSON parsing fails.
    public func compile(at path: URL) async throws -> Swiftlanefile {
        // Check that the manifest exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw ManifestError.notFound(path: path)
        }

        // Get the Swiftlane installation path for dependency resolution
        let installPath = try swiftlaneInstallPath()

        // Create a temporary directory for compilation
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("swiftlane-manifest-\(UUID().uuidString)")

        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            // Clean up temporary directory
            try? fileManager.removeItem(at: tempDir)
        }

        // Set up the package structure
        let sourcesDir = tempDir.appendingPathComponent("Sources")
        try fileManager.createDirectory(at: sourcesDir, withIntermediateDirectories: true)

        // Copy the user's Swiftlanefile.swift
        let manifestDestination = sourcesDir.appendingPathComponent("Swiftlanefile.swift")
        try fileManager.copyItem(at: path, to: manifestDestination)

        // Copy SwiftlaneHelpers if it exists
        let helpersDir = path.deletingLastPathComponent().appendingPathComponent("SwiftlaneHelpers")
        if fileManager.directoryExists(atPath: helpersDir.path) {
            let helpersDestination = sourcesDir.appendingPathComponent("SwiftlaneHelpers")
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
            .appendingPathComponent(".build/release/SwiftlaneManifest")

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
            let swiftlanefile = try decoder.decode(Swiftlanefile.self, from: jsonData)
            return swiftlanefile
        } catch {
            throw ManifestError.invalidOutput(details: error.localizedDescription)
        }
    }

    /// Gets the Swiftlane installation path for dependency resolution.
    ///
    /// This method determines where the Swiftlane package is installed by:
    /// 1. Finding the path to the `swiftlane` executable
    /// 2. Resolving symlinks to get the actual binary location
    /// 3. Navigating up to the package root (../../..)
    ///
    /// The path is used to reference SwiftlaneDSL in the generated Package.swift.
    ///
    /// - Returns: The URL to the Swiftlane package root directory.
    /// - Throws: `ManifestError.installPathNotFound` if the path cannot be determined.
    public func swiftlaneInstallPath() throws -> URL {
        // First, try to find the swiftlane executable in PATH
        if let executablePath = fileManager.findExecutable("swiftlane") {
            let executableURL = URL(fileURLWithPath: executablePath)

            // Resolve symlinks to get the actual binary location
            let resolvedURL: URL
            do {
                resolvedURL = try fileManager.destinationOfSymbolicLink(atPath: executableURL.path)
                    .isEmpty ? executableURL : URL(fileURLWithPath: try fileManager.destinationOfSymbolicLink(atPath: executableURL.path))
            } catch {
                resolvedURL = executableURL
            }

            // Navigate up to the package root
            // Expected structure: <package-root>/.build/release/swiftlane
            // So we go up 3 levels: ../../..
            let packageRoot = resolvedURL
                .deletingLastPathComponent() // .build/release
                .deletingLastPathComponent() // .build
                .deletingLastPathComponent() // package root

            // Verify that Package.swift exists at this location
            let packageSwiftPath = packageRoot.appendingPathComponent("Package.swift")
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: packageSwiftPath.path, isDirectory: &isDirectory),
               !isDirectory.boolValue {
                return packageRoot
            }
        }

        // If we can't find it via the executable, try the current working directory
        // This is useful during development
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let packageSwiftPath = currentDir.appendingPathComponent("Package.swift")
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: packageSwiftPath.path, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            return currentDir
        }

        throw ManifestError.installPathNotFound
    }

    // MARK: - Code Generation

    /// Generates the Package.swift manifest for compiling the user's manifest.
    ///
    /// - Parameter installPath: The path to the Swiftlane package root.
    /// - Returns: The generated Package.swift content as a string.
    private func generatePackageSwift(installPath: URL) -> String {
        """
        // swift-tools-version:6.0
        import PackageDescription

        let package = Package(
            name: "SwiftlaneManifest",
            platforms: [.macOS(.v13)],
            dependencies: [
                .package(path: "\(installPath.path)")
            ],
            targets: [
                .executableTarget(
                    name: "SwiftlaneManifest",
                    dependencies: [
                        .product(name: "SwiftlaneDSL", package: "Swiftlane")
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
        import SwiftlaneDSL

        // The user's Swiftlanefile.swift is also included in Sources/
        // It should define a global variable named 'swiftlane' of type Swiftlanefile

        // Output JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(swiftlane)
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
