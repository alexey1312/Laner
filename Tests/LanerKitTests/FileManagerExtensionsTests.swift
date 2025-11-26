import Testing
import Foundation
@testable import LanerKit

@Suite("FileManager Extensions Tests")
struct FileManagerExtensionsTests {
    @Test("findExecutable finds ls")
    func findExecutableFindLs() {
        let path = FileManager.default.findExecutable("ls")
        #expect(path != nil)
        #expect(path?.contains("ls") == true)
    }

    @Test("findExecutable returns nil for nonexistent command")
    func findExecutableReturnsNilForNonexistent() {
        let path = FileManager.default.findExecutable("definitely_does_not_exist_12345")
        #expect(path == nil)
    }

    @Test("directoryExists returns true for temp directory")
    func directoryExistsForTempDir() {
        let tempDir = FileManager.default.temporaryDirectory.path
        #expect(FileManager.default.directoryExists(atPath: tempDir))
    }

    @Test("currentDirectoryURL is not empty")
    func currentDirectoryURLIsNotEmpty() {
        let url = FileManager.default.currentDirectoryURL
        #expect(!url.path.isEmpty)
    }
}
