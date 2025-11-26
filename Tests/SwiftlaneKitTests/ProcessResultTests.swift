import Testing
@testable import SwiftlaneKit

@Suite("ProcessResult Tests")
struct ProcessResultTests {
    @Test("Success when exit code is 0")
    func successOnZeroExitCode() {
        let result = ProcessResult(exitCode: 0, stdout: "output", stderr: "", duration: .seconds(1))
        #expect(result.isSuccess)
    }

    @Test("Not success when exit code is non-zero")
    func notSuccessOnNonZeroExitCode() {
        let result = ProcessResult(exitCode: 1, stdout: "", stderr: "error", duration: .seconds(1))
        #expect(!result.isSuccess)
    }

    @Test("Combined output with only stdout")
    func combinedOutputOnlyStdout() {
        let result = ProcessResult(exitCode: 0, stdout: "hello", stderr: "", duration: .seconds(1))
        #expect(result.combinedOutput == "hello")
    }

    @Test("Combined output with only stderr")
    func combinedOutputOnlyStderr() {
        let result = ProcessResult(exitCode: 1, stdout: "", stderr: "error", duration: .seconds(1))
        #expect(result.combinedOutput == "error")
    }

    @Test("Combined output with both stdout and stderr")
    func combinedOutputBoth() {
        let result = ProcessResult(exitCode: 0, stdout: "hello", stderr: "warning", duration: .seconds(1))
        #expect(result.combinedOutput == "hello\nwarning")
    }

    @Test("Equality works correctly")
    func equality() {
        let result1 = ProcessResult(exitCode: 0, stdout: "hello", stderr: "", duration: .seconds(1))
        let result2 = ProcessResult(exitCode: 0, stdout: "hello", stderr: "", duration: .seconds(1))
        #expect(result1 == result2)
    }
}
