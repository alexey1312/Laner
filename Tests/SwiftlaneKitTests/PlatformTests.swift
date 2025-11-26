import Testing
@testable import SwiftlaneKit

@Suite("Platform Tests")
struct PlatformTests {
    @Test("isMacOS returns true on macOS")
    func isMacOSReturnsCorrectValue() {
        #if os(macOS)
        #expect(Platform.isMacOS)
        #expect(!Platform.isLinux)
        #else
        #expect(!Platform.isMacOS)
        #endif
    }

    @Test("isLinux returns correct value")
    func isLinuxReturnsCorrectValue() {
        #if os(Linux)
        #expect(Platform.isLinux)
        #expect(!Platform.isMacOS)
        #else
        #expect(!Platform.isLinux)
        #endif
    }

    #if os(macOS)
    @Test("macOSVersionString is not empty")
    func macOSVersionStringIsNotEmpty() {
        #expect(!Platform.macOSVersionString.isEmpty)
        // Should be in format "X.Y.Z"
        let components = Platform.macOSVersionString.split(separator: ".")
        #expect(components.count == 3)
    }
    #endif
}
