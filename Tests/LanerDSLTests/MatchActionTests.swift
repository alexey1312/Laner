import Foundation
@testable import LanerDSL
@testable import LanerMatch
import Testing

@Suite("MatchAction Tests")
struct MatchActionTests {
    @Test("MatchOptions initialization with defaults")
    func matchOptionsDefaults() {
        let options = MatchOptions(type: .development)

        #expect(options.type == .development)
        #expect(options.readonly == false)
        #expect(options.appIdentifier == nil)
        #expect(options.teamId == nil)
        #expect(options.gitUrl == nil)
        #expect(options.forceForNewDevices == false)
        #expect(options.branch == "master")
        #expect(options.password == nil)
    }

    @Test("MatchOptions initialization with custom values")
    func matchOptionsCustomValues() {
        let options = MatchOptions(
            type: .appstore,
            readonly: true,
            appIdentifier: "com.example.app",
            teamId: "TEAM123",
            gitUrl: "https://github.com/example/certs.git",
            forceForNewDevices: true,
            branch: "develop",
            password: "secret123"
        )

        #expect(options.type == .appstore)
        #expect(options.readonly == true)
        #expect(options.appIdentifier == "com.example.app")
        #expect(options.teamId == "TEAM123")
        #expect(options.gitUrl == "https://github.com/example/certs.git")
        #expect(options.forceForNewDevices == true)
        #expect(options.branch == "develop")
        #expect(options.password == "secret123")
    }

    @Test("MatchAction has correct metadata")
    func matchActionMetadata() {
        #expect(MatchAction.name == "match")
        #expect(MatchAction.description == "Sync code signing certificates and provisioning profiles")
    }

    @Test("MatchAction can be type-erased")
    func matchActionTypeErasure() {
        let options = MatchOptions(type: .development)
        let action = MatchAction(options: options)
        let anyAction = AnyAction(action)

        #expect(anyAction.name == "match")
        #expect(anyAction.description == "Sync code signing certificates and provisioning profiles")
    }

    @Test("match() DSL function creates AnyAction")
    func matchDSLFunction() {
        let action = match(type: .adhoc, readonly: true)

        #expect(action.name == "match")
    }

    @Test("match() DSL function with all parameters")
    func matchDSLFunctionAllParameters() {
        let action = match(
            type: .distribution,
            readonly: true,
            appIdentifier: "com.example.app",
            teamId: "TEAM123",
            gitUrl: "https://github.com/example/certs.git",
            forceForNewDevices: true,
            branch: "main",
            password: "test123"
        )

        #expect(action.name == "match")
    }

    @Test("MatchActionError descriptions")
    func matchActionErrorDescriptions() {
        let passwordError = MatchActionError.missingPassword
        #expect(passwordError.errorDescription?.contains("MATCH_PASSWORD") == true)

        let gitUrlError = MatchActionError.missingGitUrl
        #expect(gitUrlError.errorDescription?.contains("MATCH_GIT_URL") == true)

        let teamIdError = MatchActionError.missingTeamId
        #expect(teamIdError.errorDescription?.contains("MATCH_TEAM_ID") == true)
    }
}

@Suite("RegisterDevicesAction Tests")
struct RegisterDevicesActionTests {
    @Test("RegisterDevicesOptions initialization with file")
    func registerDevicesOptionsFile() {
        let options = RegisterDevicesOptions(file: "devices.txt")

        #expect(options.file == "devices.txt")
        #expect(options.devices == nil)
        #expect(options.platform == .iOS)
        #expect(options.teamId == nil)
        #expect(options.apiKeyId == nil)
        #expect(options.apiIssuerId == nil)
        #expect(options.apiKeyPath == nil)
    }

    @Test("RegisterDevicesOptions initialization with devices dictionary")
    func registerDevicesOptionsDevices() {
        let devices = ["iPhone 15": "00008030-001234567890401E"]
        let options = RegisterDevicesOptions(devices: devices, platform: .iOS)

        #expect(options.file == nil)
        #expect(options.devices?.count == 1)
        #expect(options.devices?["iPhone 15"] == "00008030-001234567890401E")
        #expect(options.platform == .iOS)
    }

    @Test("RegisterDevicesOptions with custom values")
    func registerDevicesOptionsCustomValues() {
        let options = RegisterDevicesOptions(
            file: "devices.txt",
            platform: .macOS,
            teamId: "TEAM123",
            apiKeyId: "KEY123",
            apiIssuerId: "ISSUER123",
            apiKeyPath: "/path/to/key.p8"
        )

        #expect(options.file == "devices.txt")
        #expect(options.platform == .macOS)
        #expect(options.teamId == "TEAM123")
        #expect(options.apiKeyId == "KEY123")
        #expect(options.apiIssuerId == "ISSUER123")
        #expect(options.apiKeyPath == "/path/to/key.p8")
    }

    @Test("RegisterDevicesAction has correct metadata")
    func registerDevicesActionMetadata() {
        #expect(RegisterDevicesAction.name == "register_devices")
        #expect(RegisterDevicesAction.description == "Register devices with Apple Developer Portal")
    }

    @Test("RegisterDevicesAction can be type-erased")
    func registerDevicesActionTypeErasure() {
        let options = RegisterDevicesOptions(file: "devices.txt")
        let action = RegisterDevicesAction(options: options)
        let anyAction = AnyAction(action)

        #expect(anyAction.name == "register_devices")
        #expect(anyAction.description == "Register devices with Apple Developer Portal")
    }

    @Test("registerDevices(file:) DSL function creates AnyAction")
    func registerDevicesDSLFunctionFile() {
        let action = registerDevices(file: "devices.txt")

        #expect(action.name == "register_devices")
    }

    @Test("registerDevices(devices:) DSL function creates AnyAction")
    func registerDevicesDSLFunctionDevices() {
        let devices = [
            "iPhone 15": "00008030-001234567890401E",
            "iPad Pro": "00008101-000123456789012E",
        ]
        let action = registerDevices(devices: devices, platform: .iOS)

        #expect(action.name == "register_devices")
    }

    @Test("registerDevices(file:) with all parameters")
    func registerDevicesDSLFunctionFileAllParameters() {
        let action = registerDevices(
            file: "devices.txt",
            platform: .tvOS,
            teamId: "TEAM123",
            apiKeyId: "KEY123",
            apiIssuerId: "ISSUER123",
            apiKeyPath: "/path/to/key.p8"
        )

        #expect(action.name == "register_devices")
    }

    @Test("RegisterDevicesActionError descriptions")
    func registerDevicesActionErrorDescriptions() {
        let noSourceError = RegisterDevicesActionError.noDeviceSource
        #expect(noSourceError.errorDescription?.contains("No device source") == true)

        let teamIdError = RegisterDevicesActionError.missingTeamId
        #expect(teamIdError.errorDescription?.contains("MATCH_TEAM_ID") == true)

        let apiKeyIdError = RegisterDevicesActionError.missingApiKeyId
        #expect(apiKeyIdError.errorDescription?.contains("APP_STORE_CONNECT_API_KEY_ID") == true)

        let apiIssuerIdError = RegisterDevicesActionError.missingApiIssuerId
        #expect(apiIssuerIdError.errorDescription?.contains("APP_STORE_CONNECT_API_ISSUER_ID") == true)

        let apiKeyPathError = RegisterDevicesActionError.missingApiKeyPath
        #expect(apiKeyPathError.errorDescription?.contains("APP_STORE_CONNECT_API_KEY_PATH") == true)
    }
}

@Suite("Match Integration Tests")
struct MatchIntegrationTests {
    @Test("MatchOptions is Sendable")
    func matchOptionsIsSendable() {
        let options = MatchOptions(type: .development)
        let sendableOptions: any Sendable = options
        #expect(sendableOptions is MatchOptions)
    }

    @Test("RegisterDevicesOptions is Sendable")
    func registerDevicesOptionsIsSendable() {
        let options = RegisterDevicesOptions(file: "devices.txt")
        let sendableOptions: any Sendable = options
        #expect(sendableOptions is RegisterDevicesOptions)
    }

    @Test("All CertificateType cases work with MatchOptions")
    func allCertificateTypes() {
        let types: [CertificateType] = [.development, .distribution, .adhoc, .appstore]

        for type in types {
            let options = MatchOptions(type: type)
            #expect(options.type == type)
        }
    }

    @Test("All Device.Platform cases work with RegisterDevicesOptions")
    func allDevicePlatforms() {
        let platforms: [Device.Platform] = [.iOS, .macOS, .tvOS, .watchOS, .visionOS]

        for platform in platforms {
            let options = RegisterDevicesOptions(file: "devices.txt", platform: platform)
            #expect(options.platform == platform)
        }
    }
}
