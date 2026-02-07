import Foundation
@testable import LanerDSL
import LanerMatch
import Testing

@Suite("ActionDispatcher Tests")
struct ActionDispatcherTests {
    @Test("Dispatcher dispatches GymAction")
    @MainActor
    func dispatchesGymAction() async throws {
        let dispatcher = ActionDispatcher()
        let action = Lanerfile.GymAction(
            scheme: "TestScheme",
            workspace: nil,
            project: nil,
            configuration: .debug,
            destination: nil,
            type: "gym"
        )
        let context = ExecutionContext()
        try await dispatcher.dispatch(action, context: context)
    }

    @Test("Dispatcher dispatches ScanAction")
    @MainActor
    func dispatchesScanAction() async throws {
        let dispatcher = ActionDispatcher()
        let action = Lanerfile.ScanAction(
            scheme: "TestScheme",
            workspace: nil,
            devices: nil,
            codeCoverage: true,
            type: "scan"
        )
        let context = ExecutionContext()
        try await dispatcher.dispatch(action, context: context)
    }

    @Test("Dispatcher dispatches ArchiveAction")
    @MainActor
    func dispatchesArchiveAction() async throws {
        let dispatcher = ActionDispatcher()
        let action = Lanerfile.ArchiveAction(
            scheme: "TestScheme",
            configuration: .release,
            exportMethod: .appStore,
            type: "archive"
        )
        let context = ExecutionContext()
        try await dispatcher.dispatch(action, context: context)
    }

    @Test("Dispatcher throws for unknown action type")
    @MainActor
    func throwsForUnknownAction() async {
        let dispatcher = ActionDispatcher()
        let action = Lanerfile.ActionImpl(type: "unknown_action")
        let context = ExecutionContext()

        await #expect(throws: ActionDispatchError.self) {
            try await dispatcher.dispatch(action, context: context)
        }
    }

    @Test("ActionDispatchError has descriptive message")
    func actionDispatchErrorDescription() {
        let error = ActionDispatchError.unknownAction(type: "foobar")
        #expect(error.errorDescription?.contains("foobar") == true)
        #expect(error.errorDescription?.contains("Unknown action type") == true)
    }

    @Test("Dispatcher executes lane with multiple actions")
    @MainActor
    func executesLaneWithMultipleActions() async throws {
        let dispatcher = ActionDispatcher()
        let lane = Lanerfile.Lane(
            name: "ci",
            description: "CI pipeline",
            actions: [
                Lanerfile.GymAction(
                    scheme: "App",
                    workspace: nil,
                    project: nil,
                    configuration: .debug,
                    destination: nil,
                    type: "gym"
                ),
                Lanerfile.ScanAction(
                    scheme: "App",
                    workspace: nil,
                    devices: nil,
                    codeCoverage: true,
                    type: "scan"
                ),
            ]
        )
        let context = ExecutionContext()
        try await dispatcher.executeLane(lane, context: context)
    }

    @Test("Dispatcher executes empty lane")
    @MainActor
    func executesEmptyLane() async throws {
        let dispatcher = ActionDispatcher()
        let lane = Lanerfile.Lane(
            name: "noop",
            description: "Does nothing",
            actions: []
        )
        let context = ExecutionContext()
        try await dispatcher.executeLane(lane, context: context)
    }

    @Test("Dispatcher dispatches MatchAction")
    @MainActor
    func dispatchesMatchAction() async throws {
        let dispatcher = ActionDispatcher()
        let action = Lanerfile.MatchAction(
            certificateType: .development,
            readonly: true,
            appIdentifier: "com.example.app",
            teamId: "TEAM123",
            gitUrl: "https://github.com/example/certs.git",
            forceForNewDevices: false,
            branch: "master",
            password: "secret",
            type: "match"
        )
        let context = ExecutionContext(environment: Environment(variables: [:]))
        // MatchAction will throw because it tries to connect to a real Git repo,
        // but we verify dispatch routes correctly by checking the error type
        do {
            _ = try await dispatcher.dispatch(action, context: context)
        } catch is ActionDispatchError {
            Issue.record("Should not throw ActionDispatchError for known action type")
        } catch {
            // Expected: MatchAction throws because it can't connect to a Git repo
        }
    }

    @Test("Dispatcher dispatches PilotAction")
    @MainActor
    func dispatchesPilotAction() async throws {
        let dispatcher = ActionDispatcher()
        let action = Lanerfile.PilotAction(
            ipa: "/nonexistent/app.ipa",
            appId: "123456789",
            changelog: "Test changelog",
            groups: ["Internal"],
            skipWaitingForProcessing: true,
            type: "pilot"
        )
        let context = ExecutionContext(environment: Environment(variables: [:]))
        // PilotAction will throw because the IPA file doesn't exist,
        // but we verify dispatch routes correctly
        do {
            _ = try await dispatcher.dispatch(action, context: context)
        } catch is ActionDispatchError {
            Issue.record("Should not throw ActionDispatchError for known action type")
        } catch {
            // Expected: PilotAction throws because IPA doesn't exist
        }
    }

    @Test("Dispatcher dispatches RegisterDevicesAction with file")
    @MainActor
    func dispatchesRegisterDevicesActionWithFile() async throws {
        let dispatcher = ActionDispatcher()
        let action = Lanerfile.RegisterDevicesAction(
            file: "devices.txt",
            devices: nil,
            platform: .iOS,
            teamId: "TEAM123",
            apiKeyId: "KEY123",
            apiIssuerId: "ISSUER123",
            apiKeyPath: "/path/to/key.p8",
            type: "register_devices"
        )
        let context = ExecutionContext(environment: Environment(variables: [:]))
        do {
            _ = try await dispatcher.dispatch(action, context: context)
        } catch is ActionDispatchError {
            Issue.record("Should not throw ActionDispatchError for known action type")
        } catch {
            // Expected: RegisterDevicesAction throws due to missing service dependencies
        }
    }

    @Test("Dispatcher dispatches RegisterDevicesAction with devices")
    @MainActor
    func dispatchesRegisterDevicesActionWithDevices() async throws {
        let dispatcher = ActionDispatcher()
        let action = Lanerfile.RegisterDevicesAction(
            file: nil,
            devices: ["iPhone": "00000000-0000000000000000"],
            platform: .iOS,
            teamId: "TEAM123",
            apiKeyId: "KEY123",
            apiIssuerId: "ISSUER123",
            apiKeyPath: "/path/to/key.p8",
            type: "register_devices"
        )
        let context = ExecutionContext(environment: Environment(variables: [:]))
        do {
            _ = try await dispatcher.dispatch(action, context: context)
        } catch is ActionDispatchError {
            Issue.record("Should not throw ActionDispatchError for known action type")
        } catch {
            // Expected: RegisterDevicesAction throws due to missing service dependencies
        }
    }

    @Test("Dispatcher throws noDeviceSource for RegisterDevicesAction without source")
    @MainActor
    func dispatchesRegisterDevicesActionThrowsWithoutSource() async throws {
        let dispatcher = ActionDispatcher()
        let action = Lanerfile.RegisterDevicesAction(
            file: nil,
            devices: nil,
            platform: .iOS,
            teamId: nil,
            apiKeyId: nil,
            apiIssuerId: nil,
            apiKeyPath: nil,
            type: "register_devices"
        )
        let context = ExecutionContext()
        await #expect(throws: RegisterDevicesActionError.self) {
            try await dispatcher.dispatch(action, context: context)
        }
    }

    @Test("Dispatcher dispatches ShellAction")
    @MainActor
    func dispatchesShellAction() async throws {
        let dispatcher = ActionDispatcher()
        let action = Lanerfile.ShellAction(
            command: "echo",
            arguments: ["hello"],
            type: "shell"
        )
        let context = ExecutionContext()
        try await dispatcher.dispatch(action, context: context)
    }
}

@Suite("ShellActionImpl Tests")
struct ShellActionImplTests {
    @Test("ShellActionImpl has correct metadata")
    func shellActionMetadata() {
        #expect(ShellActionImpl.name == "shell")
        #expect(ShellActionImpl.description == "Execute a shell command")
    }

    @Test("ShellActionOptions stores values")
    func shellActionOptionsStoresValues() {
        let options = ShellActionOptions(
            command: "echo",
            arguments: ["hello", "world"]
        )
        #expect(options.command == "echo")
        #expect(options.arguments == ["hello", "world"])
    }

    @Test("ShellActionError has descriptive message")
    func shellActionErrorDescription() {
        let error = ShellActionError.commandFailed(
            command: "make",
            exitCode: 2,
            output: "No rule to make target"
        )
        #expect(error.errorDescription?.contains("make") == true)
        #expect(error.errorDescription?.contains("exit code 2") == true)
        #expect(error.errorDescription?.contains("No rule to make target") == true)
    }

    @Test("ShellActionImpl executes echo command")
    @MainActor
    func shellActionExecutesEcho() async throws {
        let impl = ShellActionImpl(
            options: ShellActionOptions(command: "echo", arguments: ["test"])
        )
        let context = ExecutionContext()
        try await impl.execute(context: context)
    }

    @Test("ShellActionImpl throws on failure")
    @MainActor
    func shellActionThrowsOnFailure() async throws {
        let impl = ShellActionImpl(
            options: ShellActionOptions(command: "false", arguments: [])
        )
        let context = ExecutionContext()
        await #expect(throws: ShellActionError.self) {
            try await impl.execute(context: context)
        }
    }
}

// MARK: - PklTypeConversions Tests

@Suite("PklTypeConversions Tests")
struct PklTypeConversionsTests {
    @Test("BuildConfiguration conversions")
    func buildConfigurationConversions() {
        #expect(Lanerfile.BuildConfiguration.debug.toBuildConfiguration == .debug)
        #expect(Lanerfile.BuildConfiguration.release.toBuildConfiguration == .release)
    }

    @Test("ExportMethod conversions")
    func exportMethodConversions() {
        #expect(Lanerfile.ExportMethod.appStore.toExportMethod == .appStore)
        #expect(Lanerfile.ExportMethod.adHoc.toExportMethod == .adHoc)
        #expect(Lanerfile.ExportMethod.development.toExportMethod == .development)
        #expect(Lanerfile.ExportMethod.enterprise.toExportMethod == .enterprise)
    }

    @Test("CertificateType conversions")
    func certificateTypeConversions() {
        #expect(Lanerfile.CertificateType.development.toCertificateType == .development)
        #expect(Lanerfile.CertificateType.distribution.toCertificateType == .distribution)
        #expect(Lanerfile.CertificateType.adhoc.toCertificateType == .adhoc)
        #expect(Lanerfile.CertificateType.appstore.toCertificateType == .appstore)
    }

    @Test("DevicePlatform conversions")
    func devicePlatformConversions() {
        #expect(Lanerfile.DevicePlatform.iOS.toDevicePlatform == .iOS)
        #expect(Lanerfile.DevicePlatform.macOS.toDevicePlatform == .macOS)
        #expect(Lanerfile.DevicePlatform.tvOS.toDevicePlatform == .tvOS)
        #expect(Lanerfile.DevicePlatform.watchOS.toDevicePlatform == .watchOS)
        #expect(Lanerfile.DevicePlatform.visionOS.toDevicePlatform == .visionOS)
    }
}
