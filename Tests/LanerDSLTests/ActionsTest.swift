import Foundation
@testable import LanerDSL
import Testing

/// Tests for action implementations and enums.
@Suite("Action Implementation Tests")
struct ActionsTest {
    // MARK: - GymAction tests

    @Test("GymAction has correct metadata")
    func gymActionMetadata() {
        #expect(GymAction.name == "gym")
        #expect(GymAction.description == "Build an iOS/macOS app using xcodebuild")
    }

    @Test("GymAction executes without throwing")
    @MainActor
    func gymActionExecutes() async throws {
        let action = GymAction(
            options: GymOptions(
                scheme: "TestScheme",
                workspace: nil,
                project: nil,
                configuration: .debug,
                destination: nil
            )
        )
        let context = ExecutionContext()
        try await action.execute(context: context)
    }

    // MARK: - ScanAction tests

    @Test("ScanAction has correct metadata")
    func scanActionMetadata() {
        #expect(ScanAction.name == "scan")
        #expect(ScanAction.description == "Run tests using xcodebuild")
    }

    @Test("ScanAction executes without throwing")
    @MainActor
    func scanActionExecutes() async throws {
        let action = ScanAction(
            options: ScanOptions(
                scheme: "TestScheme",
                workspace: nil,
                devices: nil,
                codeCoverage: true
            )
        )
        let context = ExecutionContext()
        try await action.execute(context: context)
    }

    // MARK: - ArchiveAction tests

    @Test("ArchiveAction has correct metadata")
    func archiveActionMetadata() {
        #expect(ArchiveAction.name == "archive")
        #expect(ArchiveAction.description == "Archive an app and export an IPA")
    }

    @Test("ArchiveAction executes without throwing")
    @MainActor
    func archiveActionExecutes() async throws {
        let action = ArchiveAction(
            options: ArchiveOptions(
                scheme: "TestScheme",
                configuration: .release,
                exportMethod: .development
            )
        )
        let context = ExecutionContext()
        try await action.execute(context: context)
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
}
