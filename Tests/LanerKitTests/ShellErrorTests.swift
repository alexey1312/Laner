import Testing
@testable import LanerKit

@Suite("ShellError Tests")
struct ShellErrorTests {
    @Test("Command not found description")
    func commandNotFoundDescription() {
        let error = ShellError.commandNotFound("xcodebuild")
        #expect(error.description == "Command not found: xcodebuild")
    }

    @Test("Timeout description")
    func timeoutDescription() {
        let error = ShellError.timeout(command: "swift build", after: .seconds(60))
        #expect(error.description.contains("timed out"))
        #expect(error.description.contains("swift build"))
    }

    @Test("Execution failed description with stderr")
    func executionFailedWithStderr() {
        let error = ShellError.executionFailed(command: "swift build", exitCode: 1, stderr: "compilation error")
        #expect(error.description.contains("exit code 1"))
        #expect(error.description.contains("compilation error"))
    }

    @Test("Execution failed description without stderr")
    func executionFailedWithoutStderr() {
        let error = ShellError.executionFailed(command: "swift build", exitCode: 1, stderr: "")
        #expect(error.description.contains("exit code 1"))
        #expect(!error.description.contains(": :"))
    }

    @Test("Signal terminated description")
    func signalTerminatedDescription() {
        let error = ShellError.signalTerminated(command: "swift build", signal: 9)
        #expect(error.description.contains("signal 9"))
    }

    @Test("Setup failed description")
    func setupFailedDescription() {
        let error = ShellError.setupFailed("Invalid working directory")
        #expect(error.description.contains("Invalid working directory"))
    }

    @Test("Equality works correctly")
    func equality() {
        let error1 = ShellError.commandNotFound("xcodebuild")
        let error2 = ShellError.commandNotFound("xcodebuild")
        #expect(error1 == error2)
    }
}
