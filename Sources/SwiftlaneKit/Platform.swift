import Foundation

/// Platform detection utilities.
public enum Platform {
    /// Whether the current platform is macOS.
    public static var isMacOS: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    /// Whether the current platform is Linux.
    public static var isLinux: Bool {
        #if os(Linux)
        return true
        #else
        return false
        #endif
    }

    /// Whether the code is running in a CI environment.
    public static var isCI: Bool {
        let ciEnvironmentVariables = [
            "CI",
            "GITHUB_ACTIONS",
            "GITLAB_CI",
            "CIRCLECI",
            "TRAVIS",
            "JENKINS_URL",
            "BITRISE_IO",
            "BUILDKITE",
            "TEAMCITY_VERSION",
            "AZURE_PIPELINES",
        ]

        for envVar in ciEnvironmentVariables {
            if let value = ProcessInfo.processInfo.environment[envVar],
               !value.isEmpty {
                return true
            }
        }
        return false
    }

    /// The name of the current CI system, if detected.
    public static var ciSystemName: String? {
        if ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil {
            return "GitHub Actions"
        }
        if ProcessInfo.processInfo.environment["GITLAB_CI"] != nil {
            return "GitLab CI"
        }
        if ProcessInfo.processInfo.environment["CIRCLECI"] != nil {
            return "CircleCI"
        }
        if ProcessInfo.processInfo.environment["TRAVIS"] != nil {
            return "Travis CI"
        }
        if ProcessInfo.processInfo.environment["JENKINS_URL"] != nil {
            return "Jenkins"
        }
        if ProcessInfo.processInfo.environment["BITRISE_IO"] != nil {
            return "Bitrise"
        }
        if ProcessInfo.processInfo.environment["BUILDKITE"] != nil {
            return "Buildkite"
        }
        if ProcessInfo.processInfo.environment["TEAMCITY_VERSION"] != nil {
            return "TeamCity"
        }
        if ProcessInfo.processInfo.environment["AZURE_PIPELINES"] != nil {
            return "Azure Pipelines"
        }
        if ProcessInfo.processInfo.environment["CI"] != nil {
            return "Unknown CI"
        }
        return nil
    }

    /// The current macOS version, if running on macOS.
    #if os(macOS)
    public static var macOSVersion: OperatingSystemVersion {
        ProcessInfo.processInfo.operatingSystemVersion
    }

    /// A string representation of the macOS version.
    public static var macOSVersionString: String {
        let version = macOSVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    #endif
}
