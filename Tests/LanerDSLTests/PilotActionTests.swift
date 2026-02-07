import Foundation
@testable import LanerDSL
@testable import LanerMatch
import Testing

@Suite("PilotAction Tests")
struct PilotActionTests {
    @Test("PilotOptions initialization with defaults")
    func pilotOptionsDefaults() {
        let options = PilotOptions()

        #expect(options.ipa == nil)
        #expect(options.appId == nil)
        #expect(options.changelog == nil)
        #expect(options.groups == nil)
        #expect(options.skipWaitingForProcessing == true)
    }

    @Test("PilotOptions initialization with custom values")
    func pilotOptionsCustomValues() {
        let options = PilotOptions(
            ipa: "/path/to/app.ipa",
            appId: "123456789",
            changelog: "Bug fixes and improvements",
            groups: ["Internal", "External"],
            skipWaitingForProcessing: false
        )

        #expect(options.ipa == "/path/to/app.ipa")
        #expect(options.appId == "123456789")
        #expect(options.changelog == "Bug fixes and improvements")
        #expect(options.groups == ["Internal", "External"])
        #expect(options.skipWaitingForProcessing == false)
    }

    @Test("PilotAction has correct metadata")
    func pilotActionMetadata() {
        #expect(PilotAction.name == "pilot")
        #expect(PilotAction.description == "Upload a build to TestFlight")
    }

    @Test("PilotActionError descriptions")
    func pilotActionErrorDescriptions() {
        let missingIpaError = PilotActionError.missingIPA

        #expect(missingIpaError.errorDescription != nil)
        #expect(missingIpaError.errorDescription!.contains("IPA") == true)
    }

    @Test("PilotResult contains expected data")
    func pilotResult() {
        let build = Build(
            id: "build-123",
            version: "42",
            appVersion: "1.2.3",
            processingState: .valid
        )

        let result = PilotResult(
            build: build,
            appId: "123456789",
            ipaPath: "/path/to/app.ipa"
        )

        #expect(result.build.id == "build-123")
        #expect(result.build.version == "42")
        #expect(result.appId == "123456789")
        #expect(result.ipaPath == "/path/to/app.ipa")
    }
}

@Suite("Pilot Integration Tests")
struct PilotIntegrationTests {
    @Test("PilotOptions is Sendable")
    func pilotOptionsIsSendable() {
        let options = PilotOptions(ipa: "/path/to/app.ipa")
        let sendableOptions: any Sendable = options
        #expect(sendableOptions is PilotOptions)
    }

    @Test("PilotResult is Sendable")
    func pilotResultIsSendable() {
        let build = Build(id: "123", version: "1", processingState: .valid)
        let result = PilotResult(build: build, appId: "app123", ipaPath: "/path/to/app.ipa")
        let sendableResult: any Sendable = result
        #expect(sendableResult is PilotResult)
    }

    @Test("PilotOptions with empty groups array")
    func pilotOptionsEmptyGroups() {
        let options = PilotOptions(
            ipa: "/path/to/app.ipa",
            groups: []
        )

        #expect(options.groups != nil)
        #expect(options.groups!.isEmpty)
    }

    @Test("PilotOptions with multiple groups")
    func pilotOptionsMultipleGroups() {
        let options = PilotOptions(
            ipa: "/path/to/app.ipa",
            groups: ["Internal", "External", "QA Team", "VIP Testers"]
        )

        #expect(options.groups?.count == 4)
    }
}
