import Testing
import Foundation
import ArgumentParser
@testable import SwiftlaneCore

#if os(macOS)

// MARK: - MatchCommand Configuration Tests

@Suite("MatchCommand Configuration Tests")
struct MatchCommandConfigurationTests {
    @Test("MatchCommand has correct command name")
    func matchCommandHasCorrectCommandName() {
        #expect(MatchCommand.configuration.commandName == "match")
    }

    @Test("MatchCommand has abstract description")
    func matchCommandHasAbstractDescription() {
        let abstract = MatchCommand.configuration.abstract
        #expect(!abstract.isEmpty)
        #expect(abstract.contains("code signing") || abstract.contains("certificates") || abstract.contains("provisioning"))
    }

    @Test("MatchCommand has subcommands")
    func matchCommandHasSubcommands() {
        let subcommands = MatchCommand.configuration.subcommands
        #expect(subcommands.count == 5)
    }

    @Test("MatchCommand has sync subcommand")
    func matchCommandHasSyncSubcommand() {
        let subcommands = MatchCommand.configuration.subcommands
        #expect(subcommands.contains { $0 == MatchCommand.SyncCommand.self })
    }

    @Test("MatchCommand has init subcommand")
    func matchCommandHasInitSubcommand() {
        let subcommands = MatchCommand.configuration.subcommands
        #expect(subcommands.contains { $0 == MatchCommand.MatchInitCommand.self })
    }

    @Test("MatchCommand has nuke subcommand")
    func matchCommandHasNukeSubcommand() {
        let subcommands = MatchCommand.configuration.subcommands
        #expect(subcommands.contains { $0 == MatchCommand.NukeCommand.self })
    }

    @Test("MatchCommand has register subcommand")
    func matchCommandHasRegisterSubcommand() {
        let subcommands = MatchCommand.configuration.subcommands
        #expect(subcommands.contains { $0 == MatchCommand.RegisterCommand.self })
    }

    @Test("MatchCommand has change-password subcommand")
    func matchCommandHasChangePasswordSubcommand() {
        let subcommands = MatchCommand.configuration.subcommands
        #expect(subcommands.contains { $0 == MatchCommand.ChangePasswordCommand.self })
    }
}

// MARK: - SyncCommand Tests

@Suite("SyncCommand Configuration Tests")
struct SyncCommandConfigurationTests {
    @Test("SyncCommand has correct command name")
    func syncCommandHasCorrectCommandName() {
        #expect(MatchCommand.SyncCommand.configuration.commandName == "sync")
    }

    @Test("SyncCommand has abstract description")
    func syncCommandHasAbstractDescription() {
        let abstract = MatchCommand.SyncCommand.configuration.abstract
        #expect(!abstract.isEmpty)
        #expect(abstract.contains("certificates") || abstract.contains("profiles") || abstract.contains("Download"))
    }

    @Test("SyncCommand help text includes type option")
    func syncCommandHelpTextIncludesTypeOption() {
        let helpText = MatchCommand.SyncCommand.helpMessage()
        #expect(helpText.contains("--type") || helpText.contains("-t"))
    }

    @Test("SyncCommand help text includes readonly flag")
    func syncCommandHelpTextIncludesReadonlyFlag() {
        let helpText = MatchCommand.SyncCommand.helpMessage()
        #expect(helpText.contains("--readonly"))
    }

    @Test("SyncCommand help text includes app-identifier option")
    func syncCommandHelpTextIncludesAppIdentifierOption() {
        let helpText = MatchCommand.SyncCommand.helpMessage()
        #expect(helpText.contains("--app-identifier"))
    }

    @Test("SyncCommand help text includes git-url option")
    func syncCommandHelpTextIncludesGitUrlOption() {
        let helpText = MatchCommand.SyncCommand.helpMessage()
        #expect(helpText.contains("--git-url"))
    }

    @Test("SyncCommand help text includes team-id option")
    func syncCommandHelpTextIncludesTeamIdOption() {
        let helpText = MatchCommand.SyncCommand.helpMessage()
        #expect(helpText.contains("--team-id"))
    }

    @Test("SyncCommand help text includes branch option")
    func syncCommandHelpTextIncludesBranchOption() {
        let helpText = MatchCommand.SyncCommand.helpMessage()
        #expect(helpText.contains("--branch"))
    }

    @Test("SyncCommand type option is required")
    func syncCommandTypeOptionIsRequired() {
        // When required option is missing, parse should throw
        #expect(throws: (any Error).self) {
            _ = try MatchCommand.SyncCommand.parse([])
        }
    }

    @Test("SyncCommand parses type option with short flag")
    func syncCommandParsesTypeOptionWithShortFlag() throws {
        let command = try MatchCommand.SyncCommand.parse(["-t", "development"])
        #expect(command.type == "development")
    }

    @Test("SyncCommand parses type option with long flag")
    func syncCommandParsesTypeOptionWithLongFlag() throws {
        let command = try MatchCommand.SyncCommand.parse(["--type", "distribution"])
        #expect(command.type == "distribution")
    }

    @Test("SyncCommand readonly defaults to false")
    func syncCommandReadonlyDefaultsToFalse() throws {
        let command = try MatchCommand.SyncCommand.parse(["--type", "development"])
        #expect(command.readonly == false)
    }

    @Test("SyncCommand parses readonly flag")
    func syncCommandParsesReadonlyFlag() throws {
        let command = try MatchCommand.SyncCommand.parse(["--type", "development", "--readonly"])
        #expect(command.readonly == true)
    }

    @Test("SyncCommand app-identifier defaults to empty array")
    func syncCommandAppIdentifierDefaultsToEmptyArray() throws {
        let command = try MatchCommand.SyncCommand.parse(["--type", "development"])
        #expect(command.appIdentifier.isEmpty)
    }

    @Test("SyncCommand parses single app-identifier")
    func syncCommandParsesSingleAppIdentifier() throws {
        let command = try MatchCommand.SyncCommand.parse([
            "--type", "development",
            "--app-identifier", "com.example.app"
        ])
        #expect(command.appIdentifier == ["com.example.app"])
    }

    @Test("SyncCommand parses multiple app-identifiers")
    func syncCommandParsesMultipleAppIdentifiers() throws {
        let command = try MatchCommand.SyncCommand.parse([
            "--type", "development",
            "--app-identifier", "com.example.app1",
            "--app-identifier", "com.example.app2"
        ])
        #expect(command.appIdentifier == ["com.example.app1", "com.example.app2"])
    }

    @Test("SyncCommand git-url is optional")
    func syncCommandGitUrlIsOptional() throws {
        let command = try MatchCommand.SyncCommand.parse(["--type", "development"])
        #expect(command.gitUrl == nil)
    }

    @Test("SyncCommand parses git-url option")
    func syncCommandParsesGitUrlOption() throws {
        let command = try MatchCommand.SyncCommand.parse([
            "--type", "development",
            "--git-url", "git@github.com:example/certificates.git"
        ])
        #expect(command.gitUrl == "git@github.com:example/certificates.git")
    }

    @Test("SyncCommand team-id is optional")
    func syncCommandTeamIdIsOptional() throws {
        let command = try MatchCommand.SyncCommand.parse(["--type", "development"])
        #expect(command.teamId == nil)
    }

    @Test("SyncCommand parses team-id option")
    func syncCommandParsesTeamIdOption() throws {
        let command = try MatchCommand.SyncCommand.parse([
            "--type", "development",
            "--team-id", "ABC123DEF4"
        ])
        #expect(command.teamId == "ABC123DEF4")
    }

    @Test("SyncCommand branch defaults to master")
    func syncCommandBranchDefaultsToMaster() throws {
        let command = try MatchCommand.SyncCommand.parse(["--type", "development"])
        #expect(command.branch == "master")
    }

    @Test("SyncCommand parses branch option")
    func syncCommandParsesBranchOption() throws {
        let command = try MatchCommand.SyncCommand.parse([
            "--type", "development",
            "--branch", "main"
        ])
        #expect(command.branch == "main")
    }

    @Test("SyncCommand parses all options together")
    func syncCommandParsesAllOptionsTogether() throws {
        let command = try MatchCommand.SyncCommand.parse([
            "--type", "appstore",
            "--readonly",
            "--app-identifier", "com.example.app1",
            "--app-identifier", "com.example.app2",
            "--git-url", "git@github.com:example/certs.git",
            "--team-id", "XYZ789ABC1",
            "--branch", "production"
        ])
        #expect(command.type == "appstore")
        #expect(command.readonly == true)
        #expect(command.appIdentifier == ["com.example.app1", "com.example.app2"])
        #expect(command.gitUrl == "git@github.com:example/certs.git")
        #expect(command.teamId == "XYZ789ABC1")
        #expect(command.branch == "production")
    }
}

// MARK: - MatchInitCommand Tests

@Suite("MatchInitCommand Configuration Tests")
struct MatchInitCommandConfigurationTests {
    @Test("MatchInitCommand has correct command name")
    func matchInitCommandHasCorrectCommandName() {
        #expect(MatchCommand.MatchInitCommand.configuration.commandName == "init")
    }

    @Test("MatchInitCommand has abstract description")
    func matchInitCommandHasAbstractDescription() {
        let abstract = MatchCommand.MatchInitCommand.configuration.abstract
        #expect(!abstract.isEmpty)
        #expect(abstract.contains("Initialize") || abstract.contains("configuration"))
    }

    @Test("MatchInitCommand help text includes git-url option")
    func matchInitCommandHelpTextIncludesGitUrlOption() {
        let helpText = MatchCommand.MatchInitCommand.helpMessage()
        #expect(helpText.contains("--git-url"))
    }

    @Test("MatchInitCommand help text includes team-id option")
    func matchInitCommandHelpTextIncludesTeamIdOption() {
        let helpText = MatchCommand.MatchInitCommand.helpMessage()
        #expect(helpText.contains("--team-id"))
    }

    @Test("MatchInitCommand help text includes branch option")
    func matchInitCommandHelpTextIncludesBranchOption() {
        let helpText = MatchCommand.MatchInitCommand.helpMessage()
        #expect(helpText.contains("--branch"))
    }

    @Test("MatchInitCommand help text includes skip-setup flag")
    func matchInitCommandHelpTextIncludesSkipSetupFlag() {
        let helpText = MatchCommand.MatchInitCommand.helpMessage()
        #expect(helpText.contains("--skip-setup"))
    }

    @Test("MatchInitCommand git-url is required")
    func matchInitCommandGitUrlIsRequired() {
        #expect(throws: (any Error).self) {
            _ = try MatchCommand.MatchInitCommand.parse(["--team-id", "ABC123"])
        }
    }

    @Test("MatchInitCommand team-id is required")
    func matchInitCommandTeamIdIsRequired() {
        #expect(throws: (any Error).self) {
            _ = try MatchCommand.MatchInitCommand.parse(["--git-url", "git@github.com:test/certs.git"])
        }
    }

    @Test("MatchInitCommand parses required options")
    func matchInitCommandParsesRequiredOptions() throws {
        let command = try MatchCommand.MatchInitCommand.parse([
            "--git-url", "git@github.com:example/certificates.git",
            "--team-id", "ABC123DEF4"
        ])
        #expect(command.gitUrl == "git@github.com:example/certificates.git")
        #expect(command.teamId == "ABC123DEF4")
    }

    @Test("MatchInitCommand branch defaults to master")
    func matchInitCommandBranchDefaultsToMaster() throws {
        let command = try MatchCommand.MatchInitCommand.parse([
            "--git-url", "git@github.com:example/certs.git",
            "--team-id", "ABC123"
        ])
        #expect(command.branch == "master")
    }

    @Test("MatchInitCommand parses branch option")
    func matchInitCommandParsesBranchOption() throws {
        let command = try MatchCommand.MatchInitCommand.parse([
            "--git-url", "git@github.com:example/certs.git",
            "--team-id", "ABC123",
            "--branch", "develop"
        ])
        #expect(command.branch == "develop")
    }

    @Test("MatchInitCommand skip-setup defaults to false")
    func matchInitCommandSkipSetupDefaultsToFalse() throws {
        let command = try MatchCommand.MatchInitCommand.parse([
            "--git-url", "git@github.com:example/certs.git",
            "--team-id", "ABC123"
        ])
        #expect(command.skipSetup == false)
    }

    @Test("MatchInitCommand parses skip-setup flag")
    func matchInitCommandParsesSkipSetupFlag() throws {
        let command = try MatchCommand.MatchInitCommand.parse([
            "--git-url", "git@github.com:example/certs.git",
            "--team-id", "ABC123",
            "--skip-setup"
        ])
        #expect(command.skipSetup == true)
    }
}

// MARK: - NukeCommand Tests

@Suite("NukeCommand Configuration Tests")
struct NukeCommandConfigurationTests {
    @Test("NukeCommand has correct command name")
    func nukeCommandHasCorrectCommandName() {
        #expect(MatchCommand.NukeCommand.configuration.commandName == "nuke")
    }

    @Test("NukeCommand has abstract description")
    func nukeCommandHasAbstractDescription() {
        let abstract = MatchCommand.NukeCommand.configuration.abstract
        #expect(!abstract.isEmpty)
        #expect(abstract.contains("Revoke") || abstract.contains("remove") || abstract.contains("DESTRUCTIVE"))
    }

    @Test("NukeCommand help text includes type option")
    func nukeCommandHelpTextIncludesTypeOption() {
        let helpText = MatchCommand.NukeCommand.helpMessage()
        #expect(helpText.contains("--type") || helpText.contains("-t"))
    }

    @Test("NukeCommand help text includes force flag")
    func nukeCommandHelpTextIncludesForceFlag() {
        let helpText = MatchCommand.NukeCommand.helpMessage()
        #expect(helpText.contains("--force"))
    }

    @Test("NukeCommand type option is required")
    func nukeCommandTypeOptionIsRequired() {
        #expect(throws: (any Error).self) {
            _ = try MatchCommand.NukeCommand.parse([])
        }
    }

    @Test("NukeCommand parses type option with short flag")
    func nukeCommandParsesTypeOptionWithShortFlag() throws {
        let command = try MatchCommand.NukeCommand.parse(["-t", "development"])
        #expect(command.type == "development")
    }

    @Test("NukeCommand parses type option with long flag")
    func nukeCommandParsesTypeOptionWithLongFlag() throws {
        let command = try MatchCommand.NukeCommand.parse(["--type", "distribution"])
        #expect(command.type == "distribution")
    }

    @Test("NukeCommand force defaults to false")
    func nukeCommandForceDefaultsToFalse() throws {
        let command = try MatchCommand.NukeCommand.parse(["--type", "development"])
        #expect(command.force == false)
    }

    @Test("NukeCommand parses force flag")
    func nukeCommandParsesForceFlag() throws {
        let command = try MatchCommand.NukeCommand.parse(["--type", "development", "--force"])
        #expect(command.force == true)
    }

    @Test("NukeCommand accepts valid certificate types")
    func nukeCommandAcceptsValidCertificateTypes() throws {
        let types = ["development", "distribution", "adhoc", "appstore"]
        for type in types {
            let command = try MatchCommand.NukeCommand.parse(["--type", type])
            #expect(command.type == type)
        }
    }
}

// MARK: - RegisterCommand Tests

@Suite("RegisterCommand Configuration Tests")
struct RegisterCommandConfigurationTests {
    @Test("RegisterCommand has correct command name")
    func registerCommandHasCorrectCommandName() {
        #expect(MatchCommand.RegisterCommand.configuration.commandName == "register")
    }

    @Test("RegisterCommand has abstract description")
    func registerCommandHasAbstractDescription() {
        let abstract = MatchCommand.RegisterCommand.configuration.abstract
        #expect(!abstract.isEmpty)
        #expect(abstract.contains("Register") || abstract.contains("devices"))
    }

    @Test("RegisterCommand help text includes devices-file option")
    func registerCommandHelpTextIncludesDevicesFileOption() {
        let helpText = MatchCommand.RegisterCommand.helpMessage()
        #expect(helpText.contains("--devices-file"))
    }

    @Test("RegisterCommand help text includes platform option")
    func registerCommandHelpTextIncludesPlatformOption() {
        let helpText = MatchCommand.RegisterCommand.helpMessage()
        #expect(helpText.contains("--platform"))
    }

    @Test("RegisterCommand devices-file is required")
    func registerCommandDevicesFileIsRequired() {
        #expect(throws: (any Error).self) {
            _ = try MatchCommand.RegisterCommand.parse([])
        }
    }

    @Test("RegisterCommand parses devices-file option")
    func registerCommandParsesDevicesFileOption() throws {
        let command = try MatchCommand.RegisterCommand.parse([
            "--devices-file", "/path/to/devices.txt"
        ])
        #expect(command.devicesFile == "/path/to/devices.txt")
    }

    @Test("RegisterCommand platform defaults to iOS")
    func registerCommandPlatformDefaultsToIOS() throws {
        let command = try MatchCommand.RegisterCommand.parse([
            "--devices-file", "/path/to/devices.txt"
        ])
        #expect(command.platform == "iOS")
    }

    @Test("RegisterCommand parses platform option")
    func registerCommandParsesPlatformOption() throws {
        let command = try MatchCommand.RegisterCommand.parse([
            "--devices-file", "/path/to/devices.txt",
            "--platform", "macOS"
        ])
        #expect(command.platform == "macOS")
    }

    @Test("RegisterCommand accepts valid platforms")
    func registerCommandAcceptsValidPlatforms() throws {
        let platforms = ["iOS", "macOS", "tvOS"]
        for platform in platforms {
            let command = try MatchCommand.RegisterCommand.parse([
                "--devices-file", "/path/to/devices.txt",
                "--platform", platform
            ])
            #expect(command.platform == platform)
        }
    }
}

// MARK: - ChangePasswordCommand Tests

@Suite("ChangePasswordCommand Configuration Tests")
struct ChangePasswordCommandConfigurationTests {
    @Test("ChangePasswordCommand has correct command name")
    func changePasswordCommandHasCorrectCommandName() {
        #expect(MatchCommand.ChangePasswordCommand.configuration.commandName == "change-password")
    }

    @Test("ChangePasswordCommand has abstract description")
    func changePasswordCommandHasAbstractDescription() {
        let abstract = MatchCommand.ChangePasswordCommand.configuration.abstract
        #expect(!abstract.isEmpty)
        #expect(abstract.contains("encrypt") || abstract.contains("password"))
    }

    @Test("ChangePasswordCommand help text includes new-password option")
    func changePasswordCommandHelpTextIncludesNewPasswordOption() {
        let helpText = MatchCommand.ChangePasswordCommand.helpMessage()
        #expect(helpText.contains("--new-password"))
    }

    @Test("ChangePasswordCommand new-password is optional")
    func changePasswordCommandNewPasswordIsOptional() throws {
        let command = try MatchCommand.ChangePasswordCommand.parse([])
        #expect(command.newPassword == nil)
    }

    @Test("ChangePasswordCommand parses new-password option")
    func changePasswordCommandParsesNewPasswordOption() throws {
        let command = try MatchCommand.ChangePasswordCommand.parse([
            "--new-password", "my-new-secure-password"
        ])
        #expect(command.newPassword == "my-new-secure-password")
    }
}

// MARK: - Global Options Integration Tests

@Suite("MatchCommand Global Options Tests")
struct MatchCommandGlobalOptionsTests {
    @Test("SyncCommand includes global options")
    func syncCommandIncludesGlobalOptions() throws {
        let command = try MatchCommand.SyncCommand.parse([
            "--type", "development",
            "--verbose"
        ])
        #expect(command.globalOptions.verbosity == .verbose)
    }

    @Test("SyncCommand global options work with command options")
    func syncCommandGlobalOptionsWorkWithCommandOptions() throws {
        let command = try MatchCommand.SyncCommand.parse([
            "--verbose",
            "--type", "development",
            "--readonly",
            "--quiet"
        ])
        #expect(command.type == "development")
        #expect(command.readonly == true)
        #expect(command.globalOptions.verbosity == .quiet)
    }

    @Test("NukeCommand includes global options")
    func nukeCommandIncludesGlobalOptions() throws {
        let command = try MatchCommand.NukeCommand.parse([
            "--type", "development",
            "--verbose"
        ])
        #expect(command.globalOptions.verbosity == .verbose)
    }

    @Test("RegisterCommand includes global options")
    func registerCommandIncludesGlobalOptions() throws {
        let command = try MatchCommand.RegisterCommand.parse([
            "--devices-file", "/path/to/devices.txt",
            "--quiet"
        ])
        #expect(command.globalOptions.verbosity == .quiet)
    }
}

#else

// MARK: - Linux Platform Tests

@Suite("MatchCommand Linux Platform Tests")
struct MatchCommandLinuxTests {
    @Test("MatchCommand shows platform not supported on Linux")
    func matchCommandShowsPlatformNotSupportedOnLinux() {
        let abstract = MatchCommand.configuration.abstract
        #expect(abstract.contains("macOS only"))
    }
}

#endif
