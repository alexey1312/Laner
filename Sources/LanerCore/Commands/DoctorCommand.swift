import ArgumentParser
import Foundation
import LanerKit
import Logging

/// Checks the environment for required tools and configuration.
public struct DoctorCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check environment for required tools and configuration"
    )

    @OptionGroup var globalOptions: GlobalOptions

    public init() {}

    public func run() async throws {
        LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)

        print("Laner Doctor")
        print("================")
        print("")

        var allPassed = true

        // Check Swift
        let swiftCheck = await checkSwift()
        printCheckResult("Swift", swiftCheck)
        if !swiftCheck.passed { allPassed = false }

        // Check Git
        let gitCheck = await checkGit()
        printCheckResult("Git", gitCheck)
        if !gitCheck.passed { allPassed = false }

        #if os(macOS)
            // Check Xcode (macOS only)
            let xcodeCheck = await checkXcode()
            printCheckResult("Xcode", xcodeCheck)
            if !xcodeCheck.passed { allPassed = false }

            // Check xcodebuild
            let xcodebuildCheck = await checkXcodebuild()
            printCheckResult("xcodebuild", xcodebuildCheck)
            if !xcodebuildCheck.passed { allPassed = false }

            // Check code signing tools
            let codesignCheck = await checkCodesign()
            printCheckResult("codesign", codesignCheck)
            if !codesignCheck.passed { allPassed = false }
        #else
            print("Note: Running on Linux - Xcode tools not available")
            print("")
        #endif

        // Summary
        print("")
        if allPassed {
            print("✓ All checks passed")
        } else {
            print("✗ Some checks failed - see above for details")
            throw ExitCode.failure
        }
    }

    private struct CheckResult {
        let passed: Bool
        let version: String?
        let message: String?

        static func success(version: String) -> CheckResult {
            CheckResult(passed: true, version: version, message: nil)
        }

        static func failure(message: String) -> CheckResult {
            CheckResult(passed: false, version: nil, message: message)
        }
    }

    private func printCheckResult(_ name: String, _ result: CheckResult) {
        let icon = result.passed ? "✓" : "✗"
        if let version = result.version {
            print("\(icon) \(name): \(version)")
        } else if let message = result.message {
            print("\(icon) \(name): \(message)")
        } else {
            print("\(icon) \(name)")
        }
    }

    private func checkSwift() async -> CheckResult {
        do {
            let shell = ShellExecutor()
            let result = try await shell.run("swift", arguments: ["--version"])
            if result.isSuccess {
                // Parse version from output like "swift-driver version: 1.87.1 Apple Swift version 5.9.2"
                let output = result.stdout
                if let range = output.range(of: "Swift version [0-9.]+", options: .regularExpression) {
                    let version = String(output[range]).replacingOccurrences(of: "Swift version ", with: "")
                    return .success(version: version)
                }
                return .success(version: output.components(separatedBy: .newlines).first ?? "Unknown")
            }
            return .failure(message: "Failed to get version")
        } catch {
            return .failure(message: "Not found - install Swift from swift.org")
        }
    }

    private func checkGit() async -> CheckResult {
        do {
            let shell = ShellExecutor()
            let result = try await shell.run("git", arguments: ["--version"])
            if result.isSuccess {
                // Parse "git version 2.39.3"
                let version = result.stdout.replacingOccurrences(of: "git version ", with: "")
                return .success(version: version)
            }
            return .failure(message: "Failed to get version")
        } catch {
            return .failure(message: "Not found - install Git")
        }
    }

    #if os(macOS)
        private func checkXcode() async -> CheckResult {
            do {
                let shell = ShellExecutor()
                // Check if Xcode is selected
                let selectResult = try await shell.run("xcode-select", arguments: ["-p"])
                if !selectResult.isSuccess {
                    return .failure(message: "No Xcode selected - run 'xcode-select --install'")
                }

                // Get Xcode version
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
                task.arguments = ["-version"]

                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = FileHandle.nullDevice

                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    if let firstLine = lines.first, !firstLine.isEmpty {
                        return .success(version: firstLine.replacingOccurrences(of: "Xcode ", with: ""))
                    }
                }
                return .failure(message: "Unable to determine version")
            } catch {
                return .failure(message: "Not installed - download from App Store")
            }
        }

        private func checkXcodebuild() async -> CheckResult {
            let fileManager = FileManager.default
            guard let path = fileManager.findExecutable("xcodebuild") else {
                return .failure(message: "Not found - install Xcode Command Line Tools")
            }
            return .success(version: "Available at \(path)")
        }

        private func checkCodesign() async -> CheckResult {
            let fileManager = FileManager.default
            guard let path = fileManager.findExecutable("codesign") else {
                return .failure(message: "Not found")
            }
            return .success(version: "Available at \(path)")
        }
    #endif
}
