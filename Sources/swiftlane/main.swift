// swiftlane - CLI executable
// Entry point for the Swiftlane command-line tool.

import ArgumentParser
import SwiftlaneCore
import SwiftlaneKit

@main
struct SwiftlaneCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftlane",
        abstract: "A Swift-native CI/CD automation tool",
        version: swiftlaneVersion,
        subcommands: [
            VersionCommand.self,
            DoctorCommand.self,
            InitCommand.self,
            LanesCommand.self,
            LaneCommand.self,
            BuildCommand.self,
            TestCommand.self,
            MatchCommand.self,
            UploadCommand.self,
        ]
    )
}
