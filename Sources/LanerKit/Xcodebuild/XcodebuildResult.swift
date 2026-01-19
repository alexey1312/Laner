#if os(macOS)
    import Foundation

    /// The result of a build operation.
    public struct BuildResult: Sendable {
        /// Whether the build succeeded.
        public let succeeded: Bool

        /// The raw output from xcodebuild.
        public let output: String

        /// The duration of the build.
        public let duration: Duration

        /// Any warnings extracted from the output.
        public let warnings: [String]

        /// Any errors extracted from the output.
        public let errors: [String]

        /// Creates a build result.
        public init(
            succeeded: Bool,
            output: String,
            duration: Duration,
            warnings: [String] = [],
            errors: [String] = []
        ) {
            self.succeeded = succeeded
            self.output = output
            self.duration = duration
            self.warnings = warnings
            self.errors = errors
        }
    }

    /// The result of a test operation.
    public struct TestResult: Sendable {
        /// Whether all tests passed.
        public let succeeded: Bool

        /// The raw output from xcodebuild.
        public let output: String

        /// The duration of the test run.
        public let duration: Duration

        /// The number of tests that passed.
        public let testsPassed: Int

        /// The number of tests that failed.
        public let testsFailed: Int

        /// The number of tests that were skipped.
        public let testsSkipped: Int

        /// Any test failure messages.
        public let failures: [String]

        /// Creates a test result.
        public init(
            succeeded: Bool,
            output: String,
            duration: Duration,
            testsPassed: Int = 0,
            testsFailed: Int = 0,
            testsSkipped: Int = 0,
            failures: [String] = []
        ) {
            self.succeeded = succeeded
            self.output = output
            self.duration = duration
            self.testsPassed = testsPassed
            self.testsFailed = testsFailed
            self.testsSkipped = testsSkipped
            self.failures = failures
        }

        /// The total number of tests.
        public var totalTests: Int {
            testsPassed + testsFailed + testsSkipped
        }
    }

    /// The result of an archive operation.
    public struct ArchiveResult: Sendable {
        /// Whether the archive succeeded.
        public let succeeded: Bool

        /// The raw output from xcodebuild.
        public let output: String

        /// The duration of the archive.
        public let duration: Duration

        /// The path to the created archive.
        public let archivePath: String?

        /// Creates an archive result.
        public init(
            succeeded: Bool,
            output: String,
            duration: Duration,
            archivePath: String? = nil
        ) {
            self.succeeded = succeeded
            self.output = output
            self.duration = duration
            self.archivePath = archivePath
        }
    }

    /// The result of an export operation.
    public struct ExportResult: Sendable {
        /// Whether the export succeeded.
        public let succeeded: Bool

        /// The raw output from xcodebuild.
        public let output: String

        /// The duration of the export.
        public let duration: Duration

        /// The path to the exported IPA or app.
        public let exportPath: String?

        /// Creates an export result.
        public init(
            succeeded: Bool,
            output: String,
            duration: Duration,
            exportPath: String? = nil
        ) {
            self.succeeded = succeeded
            self.output = output
            self.duration = duration
            self.exportPath = exportPath
        }
    }
#endif
