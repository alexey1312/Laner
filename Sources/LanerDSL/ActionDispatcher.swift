import Foundation
import LanerKit
import LanerMatch
import Logging

/// Dispatches Pkl-defined actions to their Swift implementations.
///
/// `ActionDispatcher` bridges the gap between declarative Pkl configuration
/// and the existing action execution infrastructure. It maps each Pkl action
/// type to the corresponding Swift `Action` implementation and executes it.
public struct ActionDispatcher: Sendable {
    private let logger: Logger

    public init(logger: Logger = Logger.laner(.dsl)) {
        self.logger = logger
    }

    /// Executes a single Pkl action within the given context.
    @MainActor
    public func dispatch(_ action: any Lanerfile.Action, context: ExecutionContext) async throws {
        switch action {
        case let gym as Lanerfile.GymAction:
            try await executeGym(gym, context: context)
        case let scan as Lanerfile.ScanAction:
            try await executeScan(scan, context: context)
        case let archive as Lanerfile.ArchiveAction:
            try await executeArchive(archive, context: context)
        case let match as Lanerfile.MatchAction:
            try await executeMatch(match, context: context)
        case let pilot as Lanerfile.PilotAction:
            try await executePilot(pilot, context: context)
        case let register as Lanerfile.RegisterDevicesAction:
            try await executeRegisterDevices(register, context: context)
        case let shell as Lanerfile.ShellAction:
            try await executeShell(shell, context: context)
        default:
            throw ActionDispatchError.unknownAction(type: action.type)
        }
    }

    /// Executes all actions in a lane sequentially.
    @MainActor
    public func executeLane(_ lane: Lanerfile.Lane, context: ExecutionContext) async throws {
        logger.info("Executing lane '\(lane.name)' with \(lane.actions.count) action(s)")

        for (index, action) in lane.actions.enumerated() {
            logger.debug("Action \(index + 1)/\(lane.actions.count): \(action.type)")
            try await dispatch(action, context: context)
        }
    }

    // MARK: - Action Execution

    private func executeGym(_ action: Lanerfile.GymAction, context: ExecutionContext) async throws {
        let impl = GymAction(
            options: GymOptions(
                scheme: action.scheme,
                workspace: action.workspace,
                project: action.project,
                configuration: action.configuration.toBuildConfiguration,
                destination: action.destination
            )
        )
        try await impl.execute(context: context)
    }

    private func executeScan(_ action: Lanerfile.ScanAction, context: ExecutionContext) async throws {
        let impl = ScanAction(
            options: ScanOptions(
                scheme: action.scheme,
                workspace: action.workspace,
                devices: action.devices,
                codeCoverage: action.codeCoverage
            )
        )
        try await impl.execute(context: context)
    }

    private func executeArchive(_ action: Lanerfile.ArchiveAction, context: ExecutionContext) async throws {
        let impl = ArchiveAction(
            options: ArchiveOptions(
                scheme: action.scheme,
                configuration: action.configuration.toBuildConfiguration,
                exportMethod: action.exportMethod.toExportMethod
            )
        )
        try await impl.execute(context: context)
    }

    private func executeMatch(_ action: Lanerfile.MatchAction, context: ExecutionContext) async throws {
        let impl = MatchAction(
            options: MatchOptions(
                type: action.certificateType.toCertificateType,
                readonly: action.readonly,
                appIdentifier: action.appIdentifier,
                teamId: action.teamId,
                gitUrl: action.gitUrl,
                forceForNewDevices: action.forceForNewDevices,
                branch: action.branch,
                password: action.password
            )
        )
        _ = try await impl.execute(context: context)
    }

    private func executePilot(_ action: Lanerfile.PilotAction, context: ExecutionContext) async throws {
        let impl = PilotAction(
            options: PilotOptions(
                ipa: action.ipa,
                appId: action.appId,
                changelog: action.changelog,
                groups: action.groups,
                skipWaitingForProcessing: action.skipWaitingForProcessing
            )
        )
        _ = try await impl.execute(context: context)
    }

    private func executeRegisterDevices(
        _ action: Lanerfile.RegisterDevicesAction,
        context: ExecutionContext
    ) async throws {
        let impl: RegisterDevicesAction
        if let file = action.file {
            impl = RegisterDevicesAction(
                options: RegisterDevicesOptions(
                    file: file,
                    platform: action.platform.toDevicePlatform,
                    teamId: action.teamId,
                    apiKeyId: action.apiKeyId,
                    apiIssuerId: action.apiIssuerId,
                    apiKeyPath: action.apiKeyPath
                )
            )
        } else if let devices = action.devices {
            impl = RegisterDevicesAction(
                options: RegisterDevicesOptions(
                    devices: devices,
                    platform: action.platform.toDevicePlatform,
                    teamId: action.teamId,
                    apiKeyId: action.apiKeyId,
                    apiIssuerId: action.apiIssuerId,
                    apiKeyPath: action.apiKeyPath
                )
            )
        } else {
            throw RegisterDevicesActionError.noDeviceSource
        }
        _ = try await impl.execute(context: context)
    }

    private func executeShell(_ action: Lanerfile.ShellAction, context: ExecutionContext) async throws {
        let impl = ShellActionImpl(
            options: ShellActionOptions(
                command: action.command,
                arguments: action.arguments
            )
        )
        try await impl.execute(context: context)
    }
}

/// Errors from action dispatching.
public enum ActionDispatchError: Error, LocalizedError {
    case unknownAction(type: String)

    public var errorDescription: String? {
        switch self {
        case let .unknownAction(type):
            "Unknown action type: '\(type)'. Supported: gym, scan, archive, match, pilot, register_devices, shell"
        }
    }
}
