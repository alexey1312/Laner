// Code generated from Pkl module `Lanerfile`. DO NOT EDIT.
// swiftlint:disable type_name
import PklSwift

public enum Lanerfile {}

public protocol Lanerfile_Action: PklRegisteredType, DynamicallyEquatable, Hashable, Sendable {
    var type: String { get }
}

public extension Lanerfile {
    /// Build configuration for Xcode projects.
    enum BuildConfiguration: String, CaseIterable, CodingKeyRepresentable, Decodable, Hashable, Sendable {
        case debug
        case release
    }

    /// Export method for archive actions.
    enum ExportMethod: String, CaseIterable, CodingKeyRepresentable, Decodable, Hashable, Sendable {
        case appStore = "app-store"
        case adHoc = "ad-hoc"
        case development
        case enterprise
    }

    /// Certificate type for code signing.
    enum CertificateType: String, CaseIterable, CodingKeyRepresentable, Decodable, Hashable, Sendable {
        case development
        case distribution
        case adhoc
        case appstore
    }

    /// Device platform for registration.
    enum DevicePlatform: String, CaseIterable, CodingKeyRepresentable, Decodable, Hashable, Sendable {
        case iOS
        case macOS
        case tvOS
        case watchOS
        case visionOS
    }

    /// Laner CI/CD pipeline configuration.
    ///
    /// This module defines the schema for Lanerfile.pkl files.
    /// Users amend this module to define their CI/CD lanes and actions.
    ///
    /// Example:
    /// ```pkl
    /// amends "pkl/Lanerfile.pkl"
    ///
    /// lanes {
    ///   new { name = "build"; actions { new GymAction { scheme = "App" } } }
    /// }
    /// ```
    struct Module: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "Lanerfile"

        /// The lanes defined in this configuration.
        public var lanes: [Lane]

        public init(lanes: [Lane]) {
            self.lanes = lanes
        }
    }

    /// A named sequence of actions in a CI/CD pipeline.
    struct Lane: PklRegisteredType, Decodable, Hashable, Sendable {
        public static let registeredIdentifier: String = "Lanerfile#Lane"

        /// The unique name of this lane.
        public var name: String

        /// A human-readable description of what this lane does.
        public var description: String

        /// The actions to execute in order.
        public var actions: [any Action]

        public init(name: String, description: String, actions: [any Action]) {
            self.name = name
            self.description = description
            self.actions = actions
        }

        public static func == (lhs: Lane, rhs: Lane) -> Bool {
            lhs.name == rhs.name
                && lhs.description == rhs.description
                && arrayEquals(arr1: lhs.actions, arr2: rhs.actions)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(description)
            for x in actions {
                hasher.combine(x)
            }
        }

        public init(from decoder: any Decoder) throws {
            let dec = try decoder.container(keyedBy: PklCodingKey.self)
            let name = try dec.decode(String.self, forKey: PklCodingKey(string: "name"))
            let description = try dec.decode(String.self, forKey: PklCodingKey(string: "description"))
            let actions = try dec.decode([PklSwift.PklAny].self, forKey: PklCodingKey(string: "actions"))
                .map {
                    $0.value as! any Action
                }
            self = Lane(name: name, description: description, actions: actions)
        }
    }

    typealias Action = Lanerfile_Action

    /// Base class for all pipeline actions.
    struct ActionImpl: Action {
        public static let registeredIdentifier: String = "Lanerfile#Action"

        /// Discriminator for action dispatch.
        public var type: String

        public init(type: String) {
            self.type = type
        }
    }

    /// Builds an iOS/macOS app using xcodebuild.
    struct GymAction: Action {
        public static let registeredIdentifier: String = "Lanerfile#GymAction"

        /// The Xcode scheme to build.
        public var scheme: String

        /// The workspace file path.
        public var workspace: String?

        /// The project file path.
        public var project: String?

        /// The build configuration.
        public var configuration: BuildConfiguration

        /// The build destination.
        public var destination: String?

        /// Discriminator for action dispatch.
        public var type: String

        public init(
            scheme: String,
            workspace: String?,
            project: String?,
            configuration: BuildConfiguration,
            destination: String?,
            type: String
        ) {
            self.scheme = scheme
            self.workspace = workspace
            self.project = project
            self.configuration = configuration
            self.destination = destination
            self.type = type
        }
    }

    /// Runs tests using xcodebuild.
    struct ScanAction: Action {
        public static let registeredIdentifier: String = "Lanerfile#ScanAction"

        /// The Xcode scheme to test.
        public var scheme: String

        /// The workspace file path.
        public var workspace: String?

        /// Devices to run tests on.
        public var devices: [String]?

        /// Whether to enable code coverage.
        public var codeCoverage: Bool

        /// Discriminator for action dispatch.
        public var type: String

        public init(
            scheme: String,
            workspace: String?,
            devices: [String]?,
            codeCoverage: Bool,
            type: String
        ) {
            self.scheme = scheme
            self.workspace = workspace
            self.devices = devices
            self.codeCoverage = codeCoverage
            self.type = type
        }
    }

    /// Archives an app and exports an IPA.
    struct ArchiveAction: Action {
        public static let registeredIdentifier: String = "Lanerfile#ArchiveAction"

        /// The Xcode scheme to archive.
        public var scheme: String

        /// The build configuration.
        public var configuration: BuildConfiguration

        /// The export method.
        public var exportMethod: ExportMethod

        /// Discriminator for action dispatch.
        public var type: String

        public init(
            scheme: String,
            configuration: BuildConfiguration,
            exportMethod: ExportMethod,
            type: String
        ) {
            self.scheme = scheme
            self.configuration = configuration
            self.exportMethod = exportMethod
            self.type = type
        }
    }

    /// Syncs code signing certificates and provisioning profiles.
    struct MatchAction: Action {
        public static let registeredIdentifier: String = "Lanerfile#MatchAction"

        /// The certificate type to sync.
        public var certificateType: CertificateType

        /// Whether to run in readonly mode.
        public var readonly: Bool

        /// App identifier to sync profiles for.
        public var appIdentifier: String?

        /// Team ID for code signing.
        public var teamId: String?

        /// Git repository URL for certificate storage.
        public var gitUrl: String?

        /// Force regenerate profiles when new devices are added.
        public var forceForNewDevices: Bool

        /// Git branch to use.
        public var branch: String

        /// Encryption password for certificates.
        public var password: String?

        /// Discriminator for action dispatch.
        public var type: String

        public init(
            certificateType: CertificateType,
            readonly: Bool,
            appIdentifier: String?,
            teamId: String?,
            gitUrl: String?,
            forceForNewDevices: Bool,
            branch: String,
            password: String?,
            type: String
        ) {
            self.certificateType = certificateType
            self.readonly = readonly
            self.appIdentifier = appIdentifier
            self.teamId = teamId
            self.gitUrl = gitUrl
            self.forceForNewDevices = forceForNewDevices
            self.branch = branch
            self.password = password
            self.type = type
        }
    }

    /// Uploads a build to TestFlight.
    struct PilotAction: Action {
        public static let registeredIdentifier: String = "Lanerfile#PilotAction"

        /// Path to the IPA file to upload.
        public var ipa: String?

        /// The App Store Connect app ID.
        public var appId: String?

        /// Release notes for TestFlight testers.
        public var changelog: String?

        /// Names of beta groups to distribute to.
        public var groups: [String]?

        /// Skip waiting for Apple to process the build.
        public var skipWaitingForProcessing: Bool

        /// Discriminator for action dispatch.
        public var type: String

        public init(
            ipa: String?,
            appId: String?,
            changelog: String?,
            groups: [String]?,
            skipWaitingForProcessing: Bool,
            type: String
        ) {
            self.ipa = ipa
            self.appId = appId
            self.changelog = changelog
            self.groups = groups
            self.skipWaitingForProcessing = skipWaitingForProcessing
            self.type = type
        }
    }

    /// Registers devices with Apple Developer Portal.
    struct RegisterDevicesAction: Action {
        public static let registeredIdentifier: String = "Lanerfile#RegisterDevicesAction"

        /// Path to a file containing device names and UDIDs.
        public var file: String?

        /// Dictionary of device name to UDID mappings.
        public var devices: [String: String]?

        /// Platform for the devices.
        public var platform: DevicePlatform

        /// Team ID for device registration.
        public var teamId: String?

        /// App Store Connect API key ID.
        public var apiKeyId: String?

        /// App Store Connect API issuer ID.
        public var apiIssuerId: String?

        /// Path to App Store Connect API private key (.p8).
        public var apiKeyPath: String?

        /// Discriminator for action dispatch.
        public var type: String

        public init(
            file: String?,
            devices: [String: String]?,
            platform: DevicePlatform,
            teamId: String?,
            apiKeyId: String?,
            apiIssuerId: String?,
            apiKeyPath: String?,
            type: String
        ) {
            self.file = file
            self.devices = devices
            self.platform = platform
            self.teamId = teamId
            self.apiKeyId = apiKeyId
            self.apiIssuerId = apiIssuerId
            self.apiKeyPath = apiKeyPath
            self.type = type
        }
    }

    /// Executes an arbitrary shell command.
    struct ShellAction: Action {
        public static let registeredIdentifier: String = "Lanerfile#ShellAction"

        /// The command to execute.
        public var command: String

        /// Arguments to pass to the command.
        public var arguments: [String]

        /// Discriminator for action dispatch.
        public var type: String

        public init(command: String, arguments: [String], type: String) {
            self.command = command
            self.arguments = arguments
            self.type = type
        }
    }

    /// Load the Pkl module at the given source and evaluate it into `Lanerfile.Module`.
    ///
    /// - Parameter source: The source of the Pkl module.
    static func loadFrom(source: ModuleSource) async throws -> Lanerfile.Module {
        try await PklSwift.withEvaluator { evaluator in
            try await loadFrom(evaluator: evaluator, source: source)
        }
    }

    /// Load the Pkl module at the given source and evaluate it with the given evaluator into
    /// `Lanerfile.Module`.
    ///
    /// - Parameter evaluator: The evaluator to use for evaluation.
    /// - Parameter source: The module to evaluate.
    static func loadFrom(
        evaluator: PklSwift.Evaluator,
        source: PklSwift.ModuleSource
    ) async throws -> Lanerfile.Module {
        try await evaluator.evaluateModule(source: source, as: Module.self)
    }
}
