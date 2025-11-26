import Foundation
import LanerKit

/// Git-based storage provider for certificates and provisioning profiles.
///
/// `GitStorage` provides a secure Git repository backend that supports:
/// - Shallow cloning for efficiency (depth=1)
/// - SSH key authentication via ssh-agent
/// - HTTPS authentication with basic auth tokens
/// - Automatic repository initialization if it doesn't exist
///
/// Authentication options:
/// - SSH: Uses the default ssh-agent for key-based authentication
/// - HTTPS: Set `MATCH_GIT_BASIC_AUTHORIZATION` environment variable with base64 encoded "user:token"
public actor GitStorage: StorageProvider {
    /// The Git repository URL (SSH or HTTPS).
    public let gitUrl: String

    /// The branch name to use.
    public let branch: String

    /// Shell executor for running git commands.
    private let shell: ShellExecutor

    /// File manager for file system operations.
    private let fileManager: FileManager

    /// Environment variables for authentication.
    private let environment: [String: String]

    /// Creates a new Git storage provider.
    ///
    /// - Parameters:
    ///   - gitUrl: The Git repository URL (SSH or HTTPS).
    ///   - branch: The branch name to use. Defaults to "master".
    ///   - shell: The shell executor for running commands. Defaults to shared instance.
    ///   - fileManager: The file manager for file operations. Defaults to `.default`.
    public init(
        gitUrl: String,
        branch: String = "master",
        shell: ShellExecutor = .shared,
        fileManager: FileManager = .default
    ) {
        self.gitUrl = gitUrl
        self.branch = branch
        self.shell = shell
        self.fileManager = fileManager

        // Setup authentication environment
        var env: [String: String] = [:]

        // Check for HTTPS basic auth
        if let basicAuth = ProcessInfo.processInfo.environment["MATCH_GIT_BASIC_AUTHORIZATION"] {
            // Git expects credentials in format: https://user:token@host/path
            // We'll handle this by configuring Git credential helper
            env["GIT_ASKPASS"] = "echo"
            env["GIT_USERNAME"] = ""
            env["GIT_PASSWORD"] = ""

            // Decode base64 basic auth
            if let data = Data(base64Encoded: basicAuth),
               let decoded = String(data: data, encoding: .utf8) {
                let components = decoded.split(separator: ":", maxSplits: 1)
                if components.count == 2 {
                    env["GIT_USERNAME"] = String(components[0])
                    env["GIT_PASSWORD"] = String(components[1])
                }
            }
        }

        // Disable Git terminal prompts
        env["GIT_TERMINAL_PROMPT"] = "0"

        self.environment = env
    }

    public func download(to localPath: URL) async throws {
        // Ensure the parent directory exists
        let parentPath = localPath.deletingLastPathComponent()
        if !fileManager.directoryExists(atPath: parentPath.path()) {
            try fileManager.createDirectory(at: parentPath, withIntermediateDirectories: true)
        }

        // Check if directory already exists
        if fileManager.directoryExists(atPath: localPath.path()) {
            // If it exists, pull latest changes
            try await pullRepository(at: localPath)
        } else {
            // Otherwise, clone the repository
            try await cloneRepository(to: localPath)
        }
    }

    public func upload(from localPath: URL, message: String) async throws {
        // Verify the directory exists
        guard fileManager.directoryExists(atPath: localPath.path()) else {
            throw MatchError.fileNotFound(localPath.path())
        }

        // Stage all changes
        do {
            _ = try await shell.runOrThrow(
                "git",
                arguments: ["add", "--all"],
                workingDirectory: localPath,
                environment: environment
            )
        } catch {
            throw MatchError.gitPushFailed("Failed to stage changes: \(error.localizedDescription)")
        }

        // Check if there are changes to commit
        let statusResult = try await shell.run(
            "git",
            arguments: ["status", "--porcelain"],
            workingDirectory: localPath,
            environment: environment
        )

        // If no changes, skip commit and push
        if statusResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Check if local is behind remote
            try await fetchRepository(at: localPath)

            let localCommit = try await shell.runOrThrow(
                "git",
                arguments: ["rev-parse", "HEAD"],
                workingDirectory: localPath,
                environment: environment
            ).stdout.trimmingCharacters(in: .whitespacesAndNewlines)

            let remoteCommit = try await shell.runOrThrow(
                "git",
                arguments: ["rev-parse", "origin/\(branch)"],
                workingDirectory: localPath,
                environment: environment
            ).stdout.trimmingCharacters(in: .whitespacesAndNewlines)

            if localCommit != remoteCommit {
                // Pull if behind
                try await pullRepository(at: localPath)
            }

            return
        }

        // Commit changes
        do {
            _ = try await shell.runOrThrow(
                "git",
                arguments: ["commit", "-m", message],
                workingDirectory: localPath,
                environment: environment
            )
        } catch {
            throw MatchError.gitPushFailed("Failed to commit changes: \(error.localizedDescription)")
        }

        // Push to remote
        try await pushRepository(from: localPath)
    }

    public func exists() async throws -> Bool {
        // Use git ls-remote to check if repository exists
        let result = try await shell.run(
            "git",
            arguments: ["ls-remote", "--exit-code", "--heads", gitUrl, branch],
            environment: environment
        )

        return result.isSuccess
    }

    // MARK: - Private Helpers

    private func cloneRepository(to localPath: URL) async throws {
        var arguments = [
            "clone",
            "--depth", "1",
            "--branch", branch,
            "--single-branch",
            gitUrl,
            localPath.path
        ]

        // Handle authentication for HTTPS URLs
        let authenticatedUrl = buildAuthenticatedUrl()
        if let authUrl = authenticatedUrl {
            arguments[arguments.count - 2] = authUrl
        }

        do {
            _ = try await shell.runOrThrow(
                "git",
                arguments: arguments,
                environment: environment,
                timeout: .seconds(300)
            )
        } catch let error as ShellError {
            throw mapGitError(error, operation: "clone")
        } catch {
            throw MatchError.gitCloneFailed(error.localizedDescription)
        }
    }

    private func pullRepository(at localPath: URL) async throws {
        // Fetch latest changes
        try await fetchRepository(at: localPath)

        // Reset to remote branch
        do {
            _ = try await shell.runOrThrow(
                "git",
                arguments: ["reset", "--hard", "origin/\(branch)"],
                workingDirectory: localPath,
                environment: environment
            )
        } catch let error as ShellError {
            throw mapGitError(error, operation: "pull")
        } catch {
            throw MatchError.gitCloneFailed("Failed to reset to remote: \(error.localizedDescription)")
        }
    }

    private func fetchRepository(at localPath: URL) async throws {
        do {
            _ = try await shell.runOrThrow(
                "git",
                arguments: ["fetch", "origin", branch, "--depth", "1"],
                workingDirectory: localPath,
                environment: environment,
                timeout: .seconds(300)
            )
        } catch let error as ShellError {
            throw mapGitError(error, operation: "fetch")
        } catch {
            throw MatchError.gitCloneFailed("Failed to fetch: \(error.localizedDescription)")
        }
    }

    private func pushRepository(from localPath: URL) async throws {
        do {
            _ = try await shell.runOrThrow(
                "git",
                arguments: ["push", "origin", branch],
                workingDirectory: localPath,
                environment: environment,
                timeout: .seconds(300)
            )
        } catch let error as ShellError {
            throw mapGitError(error, operation: "push")
        } catch {
            throw MatchError.gitPushFailed(error.localizedDescription)
        }
    }

    private func buildAuthenticatedUrl() -> String? {
        // Only modify HTTPS URLs
        guard gitUrl.hasPrefix("https://") else {
            return nil
        }

        // Check if we have credentials
        guard let username = environment["GIT_USERNAME"],
              let password = environment["GIT_PASSWORD"],
              !username.isEmpty,
              !password.isEmpty else {
            return nil
        }

        // Build authenticated URL: https://user:token@host/path
        let urlWithoutScheme = String(gitUrl.dropFirst("https://".count))
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? username
        let encodedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password

        return "https://\(encodedUsername):\(encodedPassword)@\(urlWithoutScheme)"
    }

    private func mapGitError(_ error: ShellError, operation: String) -> MatchError {
        switch error {
        case .executionFailed(_, _, let stderr):
            if stderr.contains("Authentication failed") ||
               stderr.contains("Permission denied") ||
               stderr.contains("Could not read from remote repository") {
                return .gitAuthenticationFailed
            }
            if operation == "push" {
                return .gitPushFailed(stderr)
            }
            return .gitCloneFailed(stderr)

        case .timeout:
            if operation == "push" {
                return .gitPushFailed("Operation timed out")
            }
            return .gitCloneFailed("Operation timed out")

        case .commandNotFound(let command):
            if operation == "push" {
                return .gitPushFailed("Git not found: \(command)")
            }
            return .gitCloneFailed("Git not found: \(command)")

        case .signalTerminated, .setupFailed:
            if operation == "push" {
                return .gitPushFailed(error.localizedDescription)
            }
            return .gitCloneFailed(error.localizedDescription)
        }
    }
}
