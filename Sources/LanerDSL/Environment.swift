import Foundation

/// Represents the execution environment including CI detection and environment variables.
public struct Environment: Sendable {
    /// Known CI providers.
    public enum CIProvider: String, Sendable {
        case githubActions = "GitHub Actions"
        case gitlabCI = "GitLab CI"
        case jenkins = "Jenkins"
        case circleci = "CircleCI"
        case travisCI = "Travis CI"
        case bitrise = "Bitrise"
        case azure = "Azure Pipelines"
        case xcode = "Xcode Cloud"
        case codemagic = "Codemagic"
        case appcenter = "App Center"
        case teamcity = "TeamCity"
        case buildkite = "Buildkite"
        case unknown = "Unknown CI"
    }

    /// The raw environment variables.
    private let variables: [String: String]

    /// Whether the code is running in a CI environment.
    public let isCI: Bool

    /// The detected CI provider, if any.
    public let ciProvider: CIProvider?

    /// The current working directory.
    public let workingDirectory: URL

    /// Creates an environment from the given variables.
    /// - Parameters:
    ///   - variables: The environment variables. Defaults to the current process environment.
    ///   - workingDirectory: The working directory. Defaults to the current directory.
    public init(
        variables: [String: String] = ProcessInfo.processInfo.environment,
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) {
        self.variables = variables
        self.workingDirectory = workingDirectory
        (isCI, ciProvider) = Self.detectCI(from: variables)
    }

    /// Accesses an environment variable by name.
    /// - Parameter key: The variable name.
    /// - Returns: The value if set, or nil.
    public subscript(key: String) -> String? {
        variables[key]
    }

    /// Gets an environment variable with a default value.
    /// - Parameters:
    ///   - key: The variable name.
    ///   - default: The default value if not set.
    /// - Returns: The value or the default.
    public func get(_ key: String, default defaultValue: String) -> String {
        variables[key] ?? defaultValue
    }

    /// Gets a required environment variable.
    /// - Parameter key: The variable name.
    /// - Returns: The value.
    /// - Throws: `EnvironmentError.missingVariable` if not set.
    public func require(_ key: String) throws -> String {
        guard let value = variables[key] else {
            throw EnvironmentError.missingVariable(key)
        }
        return value
    }

    /// Gets an environment variable as a boolean.
    /// - Parameter key: The variable name.
    /// - Returns: True if the value is "true", "1", "yes", or "on" (case-insensitive).
    public func getBool(_ key: String) -> Bool {
        guard let value = variables[key]?.lowercased() else { return false }
        return ["true", "1", "yes", "on"].contains(value)
    }

    /// Gets an environment variable as an integer.
    /// - Parameter key: The variable name.
    /// - Returns: The integer value if parseable, or nil.
    public func getInt(_ key: String) -> Int? {
        variables[key].flatMap(Int.init)
    }

    /// Returns all environment variables.
    public var all: [String: String] {
        variables
    }

    /// Detects CI environment and provider from variables.
    private static func detectCI(from variables: [String: String]) -> (Bool, CIProvider?) {
        // GitHub Actions
        if variables["GITHUB_ACTIONS"] == "true" {
            return (true, .githubActions)
        }

        // GitLab CI
        if variables["GITLAB_CI"] == "true" {
            return (true, .gitlabCI)
        }

        // Jenkins
        if variables["JENKINS_URL"] != nil {
            return (true, .jenkins)
        }

        // CircleCI
        if variables["CIRCLECI"] == "true" {
            return (true, .circleci)
        }

        // Travis CI
        if variables["TRAVIS"] == "true" {
            return (true, .travisCI)
        }

        // Bitrise
        if variables["BITRISE_IO"] == "true" {
            return (true, .bitrise)
        }

        // Azure Pipelines
        if variables["TF_BUILD"] == "True" {
            return (true, .azure)
        }

        // Xcode Cloud
        if variables["CI_XCODE_CLOUD"] == "TRUE" {
            return (true, .xcode)
        }

        // Codemagic
        if variables["CM_BUILD_ID"] != nil {
            return (true, .codemagic)
        }

        // App Center
        if variables["APPCENTER_BUILD_ID"] != nil {
            return (true, .appcenter)
        }

        // TeamCity
        if variables["TEAMCITY_VERSION"] != nil {
            return (true, .teamcity)
        }

        // Buildkite
        if variables["BUILDKITE"] == "true" {
            return (true, .buildkite)
        }

        // Generic CI detection
        if variables["CI"] == "true" || variables["CI"] == "1" {
            return (true, .unknown)
        }

        return (false, nil)
    }
}

/// Errors related to environment variable access.
public enum EnvironmentError: Error, LocalizedError {
    /// A required environment variable is missing.
    case missingVariable(String)

    public var errorDescription: String? {
        switch self {
        case let .missingVariable(name):
            "Required environment variable '\(name)' is not set"
        }
    }
}
