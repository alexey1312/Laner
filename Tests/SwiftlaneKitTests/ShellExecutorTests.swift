import Testing
import Foundation
@testable import SwiftlaneKit

@Suite("ShellExecutor Tests")
struct ShellExecutorTests {
    let executor = ShellExecutor()

    @Test("Run echo command successfully")
    func runEchoCommand() async throws {
        let result = try await executor.run("echo", arguments: ["hello world"])
        #expect(result.isSuccess)
        #expect(result.stdout == "hello world")
        #expect(result.exitCode == 0)
    }

    @Test("Run pwd command successfully")
    func runPwdCommand() async throws {
        let result = try await executor.run("pwd")
        #expect(result.isSuccess)
        #expect(!result.stdout.isEmpty)
    }

    @Test("Run command with working directory")
    func runWithWorkingDirectory() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let result = try await executor.run("pwd", workingDirectory: tempDir)
        #expect(result.isSuccess)
        // The output should contain the temp directory path (macOS uses /var/folders/...)
        let tempPath = tempDir.path
        // Resolve symlinks since /tmp may point to /private/tmp
        let resolvedTempPath = (tempPath as NSString).resolvingSymlinksInPath
        let resolvedOutput = (result.stdout as NSString).resolvingSymlinksInPath
        #expect(resolvedOutput.hasPrefix(resolvedTempPath) || resolvedTempPath.hasPrefix(resolvedOutput))
    }

    @Test("Run command with environment variable")
    func runWithEnvironmentVariable() async throws {
        let result = try await executor.run(
            "sh",
            arguments: ["-c", "echo $TEST_VAR"],
            environment: ["TEST_VAR": "test_value"]
        )
        #expect(result.isSuccess)
        #expect(result.stdout == "test_value")
    }

    @Test("Run command that exits with non-zero")
    func runCommandWithNonZeroExit() async throws {
        let result = try await executor.run("sh", arguments: ["-c", "exit 42"])
        #expect(!result.isSuccess)
        #expect(result.exitCode == 42)
    }

    @Test("runOrThrow throws on non-zero exit")
    func runOrThrowThrowsOnFailure() async throws {
        do {
            _ = try await executor.runOrThrow("sh", arguments: ["-c", "exit 1"])
            Issue.record("Expected ShellError.executionFailed to be thrown")
        } catch let error as ShellError {
            if case .executionFailed(_, let exitCode, _) = error {
                #expect(exitCode == 1)
            } else {
                Issue.record("Expected ShellError.executionFailed but got \(error)")
            }
        }
    }

    @Test("Command not found throws error")
    func commandNotFoundThrows() async throws {
        do {
            _ = try await executor.run("definitely_not_a_real_command_12345")
            Issue.record("Expected ShellError.commandNotFound to be thrown")
        } catch let error as ShellError {
            if case .commandNotFound(_) = error {
                // Expected
            } else {
                Issue.record("Expected ShellError.commandNotFound but got \(error)")
            }
        }
    }

    @Test("Capture stderr output")
    func captureStderr() async throws {
        let result = try await executor.run("sh", arguments: ["-c", "echo error >&2"])
        #expect(result.stderr == "error")
    }

    @Test("Stream output from echo")
    func streamEchoOutput() async throws {
        var lines: [String] = []
        // Use sh -c with a small delay to ensure output is captured
        let stream = await executor.stream("sh", arguments: ["-c", "echo line1; sleep 0.01"])
        for try await line in stream {
            lines.append(line)
        }
        #expect(lines.contains("line1"))
    }

    @Test("Stream multiple lines")
    func streamMultipleLines() async throws {
        var lines: [String] = []
        let stream = await executor.stream("sh", arguments: ["-c", "echo line1; echo line2; echo line3"])
        for try await line in stream {
            lines.append(line)
        }
        #expect(lines.count >= 3)
        #expect(lines.contains("line1"))
        #expect(lines.contains("line2"))
        #expect(lines.contains("line3"))
    }

    @Test("Duration is captured")
    func durationIsCaptured() async throws {
        let result = try await executor.run("sleep", arguments: ["0.1"])
        #expect(result.isSuccess)
        // Duration should be at least 0.1 seconds
        #expect(result.duration >= .milliseconds(100))
    }
}
