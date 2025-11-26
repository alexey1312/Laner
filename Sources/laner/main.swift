// laner - CLI executable
// Entry point for the Laner command-line tool.

import ArgumentParser
import LanerCore
import LanerKit

@main
struct LanerCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "laner",
        abstract: "A Swift-native CI/CD automation tool",
        version: lanerVersion,
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
