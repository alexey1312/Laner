#if os(macOS)
    import Foundation
    import Logging

    /// Executes xcodebuild commands.
    ///
    /// `XcodebuildExecutor` is a stateless struct that wraps shell execution
    /// for xcodebuild operations.
    public struct XcodebuildExecutor: Sendable {
        /// The shell executor used to run commands.
        private let shell: ShellExecutor

        /// The logger for xcodebuild operations.
        private let logger: Logger

        /// The default xcodebuild executor.
        public static let shared = XcodebuildExecutor()

        /// Creates a new xcodebuild executor.
        /// - Parameters:
        ///   - shell: The shell executor to use. Defaults to the shared instance.
        ///   - logger: The logger to use. Defaults to xcodebuild category.
        public init(
            shell: ShellExecutor = .shared,
            logger: Logger = .laner(.xcodebuild)
        ) {
            self.shell = shell
            self.logger = logger
        }

        // MARK: - Build

        /// Builds an Xcode project or workspace.
        /// - Parameter options: The build options.
        /// - Returns: The build result.
        public func build(options: BuildOptions) async throws -> BuildResult {
            let args = options.toArguments()
            logger.info("Running xcodebuild \(args.joined(separator: " "))")

            let result = try await shell.run(
                "xcodebuild",
                arguments: args,
                timeout: .seconds(1800) // 30 minutes
            )

            let (warnings, errors) = parseOutput(result.combinedOutput)

            return BuildResult(
                succeeded: result.isSuccess,
                output: result.combinedOutput,
                duration: result.duration,
                warnings: warnings,
                errors: errors
            )
        }

        // MARK: - Test

        /// Tests an Xcode project or workspace.
        /// - Parameter options: The test options.
        /// - Returns: The test result.
        public func test(options: TestOptions) async throws -> TestResult {
            let args = options.toArguments()
            logger.info("Running xcodebuild \(args.joined(separator: " "))")

            let result = try await shell.run(
                "xcodebuild",
                arguments: args,
                timeout: .seconds(3600) // 1 hour
            )

            let (passed, failed, skipped, failures) = parseTestOutput(result.combinedOutput)

            return TestResult(
                succeeded: result.isSuccess && failed == 0,
                output: result.combinedOutput,
                duration: result.duration,
                testsPassed: passed,
                testsFailed: failed,
                testsSkipped: skipped,
                failures: failures
            )
        }

        // MARK: - Archive

        /// Archives an Xcode project or workspace.
        /// - Parameter options: The archive options.
        /// - Returns: The archive result.
        public func archive(options: ArchiveOptions) async throws -> ArchiveResult {
            let args = options.toArguments()
            logger.info("Running xcodebuild \(args.joined(separator: " "))")

            let result = try await shell.run(
                "xcodebuild",
                arguments: args,
                timeout: .seconds(1800) // 30 minutes
            )

            let archivePath = result.isSuccess ? options.archivePath : nil

            return ArchiveResult(
                succeeded: result.isSuccess,
                output: result.combinedOutput,
                duration: result.duration,
                archivePath: archivePath
            )
        }

        // MARK: - Export

        /// Exports an archive.
        /// - Parameter options: The export options.
        /// - Returns: The export result.
        public func exportArchive(options: ExportOptions) async throws -> ExportResult {
            let args = options.toArguments()
            logger.info("Running xcodebuild \(args.joined(separator: " "))")

            let result = try await shell.run(
                "xcodebuild",
                arguments: args,
                timeout: .seconds(600) // 10 minutes
            )

            let exportPath = result.isSuccess ? options.exportPath : nil

            return ExportResult(
                succeeded: result.isSuccess,
                output: result.combinedOutput,
                duration: result.duration,
                exportPath: exportPath
            )
        }

        // MARK: - Output Parsing

        private func parseOutput(_ output: String) -> (warnings: [String], errors: [String]) {
            var warnings: [String] = []
            var errors: [String] = []

            for line in output.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.contains(": warning:") {
                    warnings.append(trimmed)
                } else if trimmed.contains(": error:") {
                    errors.append(trimmed)
                }
            }

            return (warnings, errors)
        }

        private func parseTestOutput(_ output: String) -> (passed: Int, failed: Int, skipped: Int, failures: [String]) {
            var passed = 0
            var failed = 0
            let skipped = 0 // Not yet parsed from output
            var failures: [String] = []

            for line in output.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Parse test results summary
                // Format: "Test Suite 'All tests' passed at 2024-01-01"
                // Format: "Executed 10 tests, with 2 failures (0 unexpected) in 1.234 (1.500) seconds"
                if trimmed.hasPrefix("Executed "), trimmed.contains(" tests") {
                    if let match = parseTestSummary(trimmed) {
                        passed = match.passed
                        failed = match.failed
                    }
                }

                // Capture failure lines
                if trimmed.contains("failed"), trimmed.contains("XCT") || trimmed.contains("Test Case") {
                    failures.append(trimmed)
                }
            }

            return (passed, failed, skipped, failures)
        }

        private func parseTestSummary(_ line: String) -> (passed: Int, failed: Int)? {
            // "Executed 10 tests, with 2 failures (0 unexpected) in 1.234 (1.500) seconds"
            let pattern = #"Executed (\d+) tests?, with (\d+) failures?"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

            let range = NSRange(line.startIndex ..< line.endIndex, in: line)
            guard let match = regex.firstMatch(in: line, range: range) else { return nil }

            guard match.numberOfRanges >= 3,
                  let totalRange = Range(match.range(at: 1), in: line),
                  let failedRange = Range(match.range(at: 2), in: line),
                  let total = Int(line[totalRange]),
                  let failedCount = Int(line[failedRange])
            else {
                return nil
            }

            return (total - failedCount, failedCount)
        }
    }
#endif
