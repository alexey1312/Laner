import Testing
import Foundation
@testable import LanerCore

// MARK: - GlobalOptions Tests

@Suite("GlobalOptions Tests")
struct GlobalOptionsTests {
    @Test("default verbosity is normal")
    func defaultVerbosityIsNormal() throws {
        let options = try GlobalOptions.parse([])
        #expect(options.verbosity == .normal)
    }

    @Test("verbose flag sets verbose verbosity")
    func verboseFlagSetsVerboseVerbosity() throws {
        let options = try GlobalOptions.parse(["--verbose"])
        #expect(options.verbosity == .verbose)
    }

    @Test("quiet flag sets quiet verbosity")
    func quietFlagSetsQuietVerbosity() throws {
        let options = try GlobalOptions.parse(["--quiet"])
        #expect(options.verbosity == .quiet)
    }

    @Test("quiet takes precedence over verbose")
    func quietTakesPrecedenceOverVerbose() throws {
        let options = try GlobalOptions.parse(["--verbose", "--quiet"])
        #expect(options.verbosity == .quiet)
    }

    @Test("working directory URL defaults to current directory")
    func workingDirectoryURLDefaultsToCurrentDirectory() throws {
        let options = try GlobalOptions.parse([])
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        #expect(options.workingDirectoryURL == currentDir)
    }

    @Test("working directory URL can be set")
    func workingDirectoryURLCanBeSet() throws {
        let options = try GlobalOptions.parse(["--directory", "/tmp/test"])
        #expect(options.workingDirectoryURL == URL(fileURLWithPath: "/tmp/test"))
    }
}

// MARK: - CLIError Tests

@Suite("CLIError Tests")
struct CLIErrorTests {
    @Test("noProjectFound has descriptive message")
    func noProjectFoundHasDescriptiveMessage() {
        let error = CLIError.noProjectFound(in: URL(fileURLWithPath: "/tmp/myproject"))
        #expect(error.errorDescription?.contains("No .xcworkspace or .xcodeproj") == true)
        #expect(error.errorDescription?.contains("/tmp/myproject") == true)
    }

    @Test("schemeDiscoveryFailed has descriptive message")
    func schemeDiscoveryFailedHasDescriptiveMessage() {
        let error = CLIError.schemeDiscoveryFailed
        #expect(error.errorDescription?.contains("scheme") == true)
    }

    @Test("buildFailed with errors has descriptive message")
    func buildFailedWithErrorsHasDescriptiveMessage() {
        let error = CLIError.buildFailed(errors: ["error1", "error2"])
        #expect(error.errorDescription?.contains("2 error(s)") == true)
    }

    @Test("buildFailed without errors has generic message")
    func buildFailedWithoutErrorsHasGenericMessage() {
        let error = CLIError.buildFailed(errors: [])
        #expect(error.errorDescription == "Build failed")
    }

    @Test("testFailed with failures has descriptive message")
    func testFailedWithFailuresHasDescriptiveMessage() {
        let error = CLIError.testFailed(failedTests: ["test1", "test2", "test3"])
        #expect(error.errorDescription?.contains("3 test(s)") == true)
    }

    @Test("invalidArgument includes the message")
    func invalidArgumentIncludesTheMessage() {
        let error = CLIError.invalidArgument("scheme cannot be empty")
        #expect(error.errorDescription?.contains("scheme cannot be empty") == true)
    }

    @Test("fileNotFound includes the path")
    func fileNotFoundIncludesThePath() {
        let error = CLIError.fileNotFound("/path/to/file.txt")
        #expect(error.errorDescription?.contains("/path/to/file.txt") == true)
    }

    @Test("platformNotSupported includes the feature")
    func platformNotSupportedIncludesTheFeature() {
        let error = CLIError.platformNotSupported("xcodebuild")
        #expect(error.errorDescription?.contains("xcodebuild") == true)
        #expect(error.errorDescription?.contains("macOS") == true)
    }
}

// MARK: - LanerExitCode Tests

@Suite("LanerExitCode Tests")
struct LanerExitCodeTests {
    @Test("success is 0")
    func successIsZero() {
        #expect(LanerExitCode.success.rawValue == 0)
    }

    @Test("failure is 1")
    func failureIsOne() {
        #expect(LanerExitCode.failure.rawValue == 1)
    }

    @Test("buildFailure is 2")
    func buildFailureIsTwo() {
        #expect(LanerExitCode.buildFailure.rawValue == 2)
    }

    @Test("testFailure is 3")
    func testFailureIsThree() {
        #expect(LanerExitCode.testFailure.rawValue == 3)
    }

    @Test("invalidUsage is EX_USAGE (64)")
    func invalidUsageIsExUsage() {
        #expect(LanerExitCode.invalidUsage.rawValue == 64)
    }

    @Test("configurationError is 78")
    func configurationErrorIs78() {
        #expect(LanerExitCode.configurationError.rawValue == 78)
    }
}

// MARK: - Command Configuration Tests

#if os(macOS)
@Suite("Command Configuration Tests")
struct CommandConfigurationTests {
    @Test("VersionCommand has correct configuration")
    func versionCommandHasCorrectConfiguration() {
        #expect(VersionCommand.configuration.commandName == "version")
    }

    @Test("DoctorCommand has correct configuration")
    func doctorCommandHasCorrectConfiguration() {
        #expect(DoctorCommand.configuration.commandName == "doctor")
    }

    @Test("BuildCommand has correct configuration")
    func buildCommandHasCorrectConfiguration() {
        #expect(BuildCommand.configuration.commandName == "build")
    }

    @Test("TestCommand has correct configuration")
    func testCommandHasCorrectConfiguration() {
        #expect(TestCommand.configuration.commandName == "test")
    }

    @Test("InitCommand has correct configuration")
    func initCommandHasCorrectConfiguration() {
        #expect(InitCommand.configuration.commandName == "init")
    }

    @Test("LanesCommand has correct configuration")
    func lanesCommandHasCorrectConfiguration() {
        #expect(LanesCommand.configuration.commandName == "lanes")
    }

    @Test("LaneCommand has correct configuration")
    func laneCommandHasCorrectConfiguration() {
        #expect(LaneCommand.configuration.commandName == "lane")
    }
}
#endif

// MARK: - ManifestCache Tests

@Suite("ManifestCache Tests")
struct ManifestCacheTests {
    @Test("Default cache directory is in home directory")
    func defaultCacheDirectoryIsInHomeDirectory() {
        let cache = ManifestCache()
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        #expect(cache.cacheDirectory.path(percentEncoded: false).hasPrefix(homeDir.path(percentEncoded: false)))
        #expect(cache.cacheDirectory.path(percentEncoded: false).contains(".laner/cache"))
    }

    @Test("Custom cache directory is used")
    func customCacheDirectoryIsUsed() {
        let customDir = URL(fileURLWithPath: "/tmp/test-cache")
        let cache = ManifestCache(cacheDirectory: customDir)
        #expect(cache.cacheDirectory == customDir)
    }

    @Test("Computes hash for nonexistent file throws")
    func computeHashForNonexistentFileThrows() throws {
        let cache = ManifestCache()
        let nonexistent = URL(fileURLWithPath: "/nonexistent/path/Lanerfile.swift")
        #expect(throws: (any Error).self) {
            try cache.computeHash(for: nonexistent)
        }
    }
}

// MARK: - ManifestError Tests

@Suite("ManifestError Tests")
struct ManifestErrorTests {
    @Test("notFound error has descriptive message")
    func notFoundErrorHasDescriptiveMessage() {
        let error = ManifestError.notFound(path: URL(fileURLWithPath: "/path/to/manifest"))
        #expect(error.errorDescription?.contains("/path/to/manifest") == true)
        #expect(error.errorDescription?.contains("not found") == true)
    }

    @Test("compilationFailed error includes output")
    func compilationFailedErrorIncludesOutput() {
        let error = ManifestError.compilationFailed(output: "compilation error")
        #expect(error.errorDescription?.contains("compilation error") == true)
    }

    @Test("executionFailed error includes output")
    func executionFailedErrorIncludesOutput() {
        let error = ManifestError.executionFailed(output: "execution error")
        #expect(error.errorDescription?.contains("execution error") == true)
    }

    @Test("invalidOutput error has message")
    func invalidOutputErrorHasMessage() {
        let error = ManifestError.invalidOutput(details: "parse error")
        #expect(error.errorDescription?.isEmpty == false)
    }
}

// MARK: - ManifestLoader Tests

@Suite("ManifestLoader Tests")
struct ManifestLoaderTests {
    @Test("manifestExists returns false for empty directory")
    func manifestExistsReturnsFalseForEmptyDirectory() {
        let loader = ManifestLoader()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        #expect(loader.manifestExists(in: tempDir) == false)
    }

    @Test("findManifestPath throws for missing manifest")
    func findManifestPathThrowsForMissingManifest() {
        let loader = ManifestLoader()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        #expect(throws: ManifestError.self) {
            _ = try loader.findManifestPath(in: tempDir)
        }
    }
}
