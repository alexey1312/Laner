import Testing
@testable import LanerKit

@Suite("LanerKit Tests")
struct LanerKitTests {
    @Test("Version string is not empty")
    func versionString() {
        #expect(!lanerVersion.isEmpty)
    }
}
