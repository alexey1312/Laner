import Testing
import Foundation
@testable import SwiftlaneDSL

/// Tests for DSL action functions (gym, scan, archive)
@Suite("DSL Action Functions Tests")
struct ActionsTest {
    // MARK: - gym() tests

    @Test("gym creates GymAction with default configuration")
    func gymCreatesActionWithDefaults() {
        let action = gym(scheme: "MyApp")

        #expect(action.name == "gym")
        #expect(action.description == "Build an iOS/macOS app using xcodebuild")
    }

    @Test("gym creates GymAction with full configuration")
    func gymCreatesActionWithFullConfiguration() {
        let action = gym(
            scheme: "MyApp",
            workspace: "MyApp.xcworkspace",
            project: nil,
            configuration: .release,
            destination: "generic/platform=iOS"
        )

        #expect(action.name == "gym")
    }

    @Test("gym executes without throwing")
    @MainActor
    func gymExecutesWithoutThrowing() async throws {
        let action = gym(scheme: "TestScheme")
        let context = ExecutionContext()

        try await action.execute(context: context)
        // If we get here without throwing, the action executed
    }

    // MARK: - scan() tests

    @Test("scan creates ScanAction with default configuration")
    func scanCreatesActionWithDefaults() {
        let action = scan(scheme: "MyApp")

        #expect(action.name == "scan")
        #expect(action.description == "Run tests using xcodebuild")
    }

    @Test("scan creates ScanAction with full configuration")
    func scanCreatesActionWithFullConfiguration() {
        let action = scan(
            scheme: "MyApp",
            workspace: "MyApp.xcworkspace",
            devices: ["iPhone 15 Pro", "iPad Pro"],
            codeCoverage: true
        )

        #expect(action.name == "scan")
    }

    @Test("scan executes without throwing")
    @MainActor
    func scanExecutesWithoutThrowing() async throws {
        let action = scan(scheme: "TestScheme", codeCoverage: true)
        let context = ExecutionContext()

        try await action.execute(context: context)
        // If we get here without throwing, the action executed
    }

    // MARK: - archive() tests

    @Test("archive creates ArchiveAction with default configuration")
    func archiveCreatesActionWithDefaults() {
        let action = archive(scheme: "MyApp")

        #expect(action.name == "archive")
        #expect(action.description == "Archive an app and export an IPA")
    }

    @Test("archive creates ArchiveAction with full configuration")
    func archiveCreatesActionWithFullConfiguration() {
        let action = archive(
            scheme: "MyApp",
            configuration: .release,
            exportMethod: .adHoc
        )

        #expect(action.name == "archive")
    }

    @Test("archive executes without throwing")
    @MainActor
    func archiveExecutesWithoutThrowing() async throws {
        let action = archive(scheme: "TestScheme", exportMethod: .development)
        let context = ExecutionContext()

        try await action.execute(context: context)
        // If we get here without throwing, the action executed
    }

    // MARK: - Enum tests

    @Test("BuildConfiguration has correct raw values")
    func buildConfigurationRawValues() {
        #expect(BuildConfiguration.debug.rawValue == "Debug")
        #expect(BuildConfiguration.release.rawValue == "Release")
    }

    @Test("ExportMethod has correct raw values")
    func exportMethodRawValues() {
        #expect(ExportMethod.appStore.rawValue == "app-store")
        #expect(ExportMethod.adHoc.rawValue == "ad-hoc")
        #expect(ExportMethod.development.rawValue == "development")
        #expect(ExportMethod.enterprise.rawValue == "enterprise")
    }

    // MARK: - Integration tests

    @Test("can use DSL functions in a lane")
    @MainActor
    func canUseDSLFunctionsInLane() async throws {
        let lane = Lane(name: "test") { context in
            try await gym(scheme: "MyApp").execute(context: context)
            try await scan(scheme: "MyApp").execute(context: context)
            try await archive(scheme: "MyApp").execute(context: context)
        }

        let context = ExecutionContext()
        try await lane.execute(context: context)
        // If we get here, all actions executed successfully
    }
}
