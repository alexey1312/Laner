import Testing
@testable import SwiftlaneKit

@Suite("SwiftlaneKit Tests")
struct SwiftlaneKitTests {
    @Test("Version string is not empty")
    func versionString() {
        #expect(!swiftlaneVersion.isEmpty)
    }
}
