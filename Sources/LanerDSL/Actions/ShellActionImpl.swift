import Foundation
import LanerKit

/// Executes an arbitrary shell command via ShellExecutor.
struct ShellActionImpl: Action {
    typealias Options = ShellActionOptions
    typealias Result = Void

    static let name = "shell"
    static let description = "Execute a shell command"

    let options: ShellActionOptions

    @MainActor
    func execute(context: ExecutionContext) async throws {
        context.logger.info(
            "[shell] Executing: \(options.command) \(options.arguments.joined(separator: " "))"
        )

        let result = try await context.shell.run(
            options.command,
            arguments: options.arguments,
            workingDirectory: context.workingDirectory,
            timeout: .seconds(600)
        )

        guard result.isSuccess else {
            let output = result.stderr.isEmpty ? result.stdout : result.stderr
            throw ShellActionError.commandFailed(
                command: options.command,
                exitCode: result.exitCode,
                output: output
            )
        }

        if !result.stdout.isEmpty {
            context.logger.info("[shell] stdout: \(result.stdout)")
        }
        if !result.stderr.isEmpty {
            context.logger.warning("[shell] stderr: \(result.stderr)")
        }
    }
}

struct ShellActionOptions: Sendable {
    let command: String
    let arguments: [String]
}

enum ShellActionError: Error, LocalizedError {
    case commandFailed(command: String, exitCode: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(command, exitCode, output):
            "Shell command '\(command)' failed with exit code \(exitCode): \(output)"
        }
    }
}
