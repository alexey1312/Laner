@testable import LanerKit
import Testing

@Suite("LanerKit Tests")
struct LanerKitTests {
    @Test("Version string is not empty")
    func versionString() {
        #expect(!lanerVersion.isEmpty)
    }
}
