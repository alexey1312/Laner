import ArgumentParser
import Foundation
import LanerKit

/// Global options available to all Laner commands.
public struct GlobalOptions: ParsableArguments {
    @Flag(name: [.short, .long], help: "Enable verbose output (debug-level logging)")
    public var verbose: Bool = false

    @Flag(name: [.short, .long], help: "Suppress all output except errors")
    public var quiet: Bool = false

    @Option(name: [.short, .long], help: "Working directory for the command")
    public var directory: String?

    public init() {}

    /// The verbosity level based on flags.
    public var verbosity: Verbosity {
        if quiet {
            return .quiet
        } else if verbose {
            return .verbose
        }
        return .normal
    }

    /// The working directory URL, defaulting to current directory.
    public var workingDirectoryURL: URL {
        if let directory {
            return URL(fileURLWithPath: directory)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}
