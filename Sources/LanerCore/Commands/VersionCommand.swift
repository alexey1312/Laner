import ArgumentParser
import Foundation
import LanerKit

/// Shows version information for Laner and the environment.
public struct VersionCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Show Laner version and environment information"
    )

    @OptionGroup var globalOptions: GlobalOptions

    public init() {}

    public func run() throws {
        LoggingConfiguration.bootstrap(verbosity: globalOptions.verbosity)

        print("Laner \(lanerVersion)")
        print("")

        // Swift version
        printSwiftVersion()

        // OS info
        printOSInfo()

        // Xcode info (macOS only)
        #if os(macOS)
            printXcodeInfo()
        #endif
    }

    private func printSwiftVersion() {
        print("Swift: \(getSwiftVersion())")
    }

    private func getSwiftVersion() -> String {
        #if swift(>=6.0)
            return "6.0+"
        #elseif swift(>=5.10)
            return "5.10+"
        #elseif swift(>=5.9)
            return "5.9+"
        #else
            return "Unknown"
        #endif
    }

    private func printOSInfo() {
        let processInfo = ProcessInfo.processInfo
        print("OS: \(processInfo.operatingSystemVersionString)")
    }

    #if os(macOS)
        private func printXcodeInfo() {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
            task.arguments = ["-version"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
                        print(line)
                    }
                }
            } catch {
                print("Xcode: Not available")
            }
        }
    #endif
}
