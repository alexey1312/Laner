import Testing
import Logging
@testable import SwiftlaneKit

@Suite("Logging Tests")
struct LoggingTests {
    @Test("LogCategory has correct labels")
    func logCategoryLabels() {
        #expect(LogCategory.shell.label == "swiftlane.shell")
        #expect(LogCategory.xcodebuild.label == "swiftlane.xcodebuild")
        #expect(LogCategory.cli.label == "swiftlane.cli")
        #expect(LogCategory.dsl.label == "swiftlane.dsl")
        #expect(LogCategory.config.label == "swiftlane.config")
        #expect(LogCategory.manifest.label == "swiftlane.manifest")
    }

    @Test("LogCategory is CaseIterable")
    func logCategoryIsCaseIterable() {
        let allCategories = LogCategory.allCases
        #expect(allCategories.count == 6)
    }

    @Test("Logger.swiftlane creates logger with correct label")
    func loggerSwiftlaneCreatesCorrectLabel() {
        let logger = Logger.swiftlane(.shell)
        #expect(logger.label == "swiftlane.shell")
    }

    @Test("Verbosity quiet maps to warning level")
    func verbosityQuietLevel() {
        #expect(Verbosity.quiet.logLevel == .warning)
    }

    @Test("Verbosity normal maps to info level")
    func verbosityNormalLevel() {
        #expect(Verbosity.normal.logLevel == .info)
    }

    @Test("Verbosity verbose maps to debug level")
    func verbosityVerboseLevel() {
        #expect(Verbosity.verbose.logLevel == .debug)
    }

    @Test("Verbosity trace maps to trace level")
    func verbosityTraceLevel() {
        #expect(Verbosity.trace.logLevel == .trace)
    }

    @Test("ConsoleLogHandler can be created")
    func consoleLogHandlerCreation() {
        let handler = ConsoleLogHandler(label: "test", useColors: false)
        #expect(handler.label == "test")
        #expect(handler.logLevel == .info)
    }

    @Test("ConsoleLogHandler metadata subscript works")
    func consoleLogHandlerMetadata() {
        var handler = ConsoleLogHandler(label: "test", useColors: false)
        handler[metadataKey: "key"] = "value"
        #expect(handler[metadataKey: "key"] == "value")
    }
}
