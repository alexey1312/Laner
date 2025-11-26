import Testing
import Foundation
@testable import SwiftlaneDSL
@testable import SwiftlaneMatch

@Suite("PilotAction Tests")
struct PilotActionTests {
    @Test("PilotOptions initialization with defaults")
    func testPilotOptionsDefaults() {
        let options = PilotOptions()

        #expect(options.ipa == nil)
        #expect(options.appId == nil)
        #expect(options.changelog == nil)
        #expect(options.groups == nil)
        #expect(options.skipWaitingForProcessing == true)
    }

    @Test("PilotOptions initialization with custom values")
    func testPilotOptionsCustomValues() {
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
    func testPilotActionMetadata() {
        #expect(PilotAction.name == "pilot")
        #expect(PilotAction.description == "Upload a build to TestFlight")
    }

    @Test("PilotAction can be type-erased")
    func testPilotActionTypeErasure() {
        let options = PilotOptions(ipa: "/path/to/app.ipa")
        let action = PilotAction(options: options)
        let anyAction = AnyAction(action)

        #expect(anyAction.name == "pilot")
        #expect(anyAction.description == "Upload a build to TestFlight")
    }

    @Test("pilot() DSL function creates AnyAction")
    func testPilotDSLFunction() {
        let action = pilot(ipa: "/path/to/app.ipa")

        #expect(action.name == "pilot")
    }

    @Test("pilot() DSL function with all parameters")
    func testPilotDSLFunctionAllParameters() {
        let action = pilot(
            ipa: "/path/to/app.ipa",
            appId: "123456789",
            changelog: "New features",
            groups: ["QA", "Beta Testers"],
            skipWaitingForProcessing: false
        )

        #expect(action.name == "pilot")
    }

    @Test("uploadToTestFlight() is an alias for pilot()")
    func testUploadToTestFlightAlias() {
        let pilotAction = pilot(
            ipa: "/path/to/app.ipa",
            appId: "123456789"
        )
        let uploadAction = uploadToTestFlight(
            ipa: "/path/to/app.ipa",
            appId: "123456789"
        )

        #expect(pilotAction.name == uploadAction.name)
    }

    @Test("PilotActionError descriptions")
    func testPilotActionErrorDescriptions() {
        let missingIpaError = PilotActionError.missingIPA

        #expect(missingIpaError.errorDescription != nil)
        #expect(missingIpaError.errorDescription!.contains("IPA") == true)
    }

    @Test("PilotResult contains expected data")
    func testPilotResult() {
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
    func testPilotOptionsIsSendable() {
        let options = PilotOptions(ipa: "/path/to/app.ipa")
        let sendableOptions: any Sendable = options
        #expect(sendableOptions is PilotOptions)
    }

    @Test("PilotResult is Sendable")
    func testPilotResultIsSendable() {
        let build = Build(id: "123", version: "1", processingState: .valid)
        let result = PilotResult(build: build, appId: "app123", ipaPath: "/path/to/app.ipa")
        let sendableResult: any Sendable = result
        #expect(sendableResult is PilotResult)
    }

    @Test("PilotOptions with empty groups array")
    func testPilotOptionsEmptyGroups() {
        let options = PilotOptions(
            ipa: "/path/to/app.ipa",
            groups: []
        )

        #expect(options.groups != nil)
        #expect(options.groups!.isEmpty)
    }

    @Test("PilotOptions with single group")
    func testPilotOptionsSingleGroup() {
        let options = PilotOptions(
            ipa: "/path/to/app.ipa",
            groups: ["Beta Testers"]
        )

        #expect(options.groups?.count == 1)
        #expect(options.groups?.first == "Beta Testers")
    }

    @Test("PilotOptions with multiple groups")
    func testPilotOptionsMultipleGroups() {
        let options = PilotOptions(
            ipa: "/path/to/app.ipa",
            groups: ["Internal", "External", "QA Team", "VIP Testers"]
        )

        #expect(options.groups?.count == 4)
    }

    @Test("pilot() works in lane context")
    func testPilotInLaneContext() {
        // Verify pilot() returns an action that can be used in a lane
        let actions = [
            pilot(ipa: "/path/to/app.ipa", appId: "123456789")
        ]

        #expect(actions.count == 1)
        #expect(actions[0].name == "pilot")
    }

    @Test("pilot() combined with other actions")
    func testPilotWithOtherActions() {
        // Simulate a typical beta release lane
        let actions: [AnyAction] = [
            match(type: .appstore, readonly: true),
            gym(scheme: "MyApp", configuration: .release),
            pilot(
                appId: "123456789",
                changelog: "Bug fixes",
                groups: ["Internal Testers"]
            )
        ]

        #expect(actions.count == 3)
        #expect(actions[0].name == "match")
        #expect(actions[1].name == "gym")
        #expect(actions[2].name == "pilot")
    }
}
