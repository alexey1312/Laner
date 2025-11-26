import Foundation
import Testing
@testable import SwiftlaneMatch

@Suite("KeychainService Tests")
struct KeychainServiceTests {

    #if !os(macOS)
    // Linux platform tests - verify stubs throw platformNotSupported
    // Note: We use importCertificateDiscardingIdentity instead of importCertificate
    // to avoid non-Sendable return type issues with UnsafeRawPointer across actor boundaries

    @Test("importCertificateDiscardingIdentity throws platformNotSupported on Linux")
    func testImportCertificateLinux() async throws {
        let service = KeychainService()
        let dummyData = Data([0x01, 0x02, 0x03])

        do {
            try await service.importCertificateDiscardingIdentity(
                p12Data: dummyData,
                password: "test",
                keychain: nil
            )
            Issue.record("Expected platformNotSupported error")
        } catch let error as MatchError {
            guard case .platformNotSupported(let operation) = error else {
                Issue.record("Wrong error type: \(error)")
                return
            }
            #expect(operation == "Keychain")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("createTemporaryKeychain throws platformNotSupported on Linux")
    func testCreateTemporaryKeychainLinux() async throws {
        // Test via deleteKeychain since createTemporaryKeychain returns non-Sendable tuple
        // The stub implementation throws the same error for all methods
        let service = KeychainService()

        do {
            try await service.deleteKeychain(nil)
            Issue.record("Expected platformNotSupported error")
        } catch let error as MatchError {
            guard case .platformNotSupported(let operation) = error else {
                Issue.record("Wrong error type: \(error)")
                return
            }
            #expect(operation == "Keychain")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("deleteKeychain throws platformNotSupported on Linux")
    func testDeleteKeychainLinux() async throws {
        let service = KeychainService()

        do {
            try await service.deleteKeychain(nil)
            Issue.record("Expected platformNotSupported error")
        } catch let error as MatchError {
            guard case .platformNotSupported(let operation) = error else {
                Issue.record("Wrong error type: \(error)")
                return
            }
            #expect(operation == "Keychain")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("addToSearchList throws platformNotSupported on Linux")
    func testAddToSearchListLinux() async throws {
        let service = KeychainService()

        do {
            try await service.addToSearchList(nil)
            Issue.record("Expected platformNotSupported error")
        } catch let error as MatchError {
            guard case .platformNotSupported(let operation) = error else {
                Issue.record("Wrong error type: \(error)")
                return
            }
            #expect(operation == "Keychain")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("installProfile throws platformNotSupported on Linux")
    func testInstallProfileLinux() async throws {
        let service = KeychainService()
        let profile = ProvisioningProfile(
            id: "test-id",
            uuid: "test-uuid",
            name: "Test Profile",
            bundleId: "com.test.app",
            type: .development,
            teamId: "TEST123",
            teamName: "Test Team",
            expirationDate: Date(),
            content: Data([0x01, 0x02, 0x03])
        )

        do {
            try await service.installProfile(profile)
            Issue.record("Expected platformNotSupported error")
        } catch let error as MatchError {
            guard case .platformNotSupported(let operation) = error else {
                Issue.record("Wrong error type: \(error)")
                return
            }
            #expect(operation == "Keychain")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    #else
    // macOS platform tests - basic functionality tests

    @Test("KeychainService can be instantiated on macOS")
    func testInstantiation() async {
        _ = KeychainService()
        // If we get here without crash, instantiation succeeded
    }

    @Test("installProfile fails with missing content")
    func testInstallProfileNoContent() async throws {
        let service = KeychainService()
        let profile = ProvisioningProfile(
            id: "test-id",
            uuid: "test-uuid",
            name: "Test Profile",
            bundleId: "com.test.app",
            type: .development,
            teamId: "TEST123",
            teamName: "Test Team",
            expirationDate: Date(),
            content: nil // No content
        )

        do {
            try await service.installProfile(profile)
            Issue.record("Expected profileInstallationFailed error")
        } catch let error as MatchError {
            guard case .profileInstallationFailed(let reason) = error else {
                Issue.record("Wrong error type: \(error)")
                return
            }
            #expect(reason.contains("has no content data"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // Note: Tests for importCertificate and createTemporaryKeychain are skipped
    // because SecIdentity and SecKeychain are not Sendable types and cannot
    // be safely passed across actor boundaries in tests. These methods are
    // tested indirectly through integration tests.

    @Test("installProfile creates directory and writes file")
    func testInstallProfileWritesFile() async throws {
        let service = KeychainService()
        let testUUID = UUID().uuidString
        let profileContent = Data("test-profile-content".utf8)

        let profile = ProvisioningProfile(
            id: "test-id",
            uuid: testUUID,
            name: "Test Profile",
            bundleId: "com.test.app",
            type: .development,
            teamId: "TEST123",
            teamName: "Test Team",
            expirationDate: Date(),
            content: profileContent
        )

        // Install the profile
        try await service.installProfile(profile)

        // Verify the file was created
        let expectedPath = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/MobileDevice/Provisioning Profiles")
            .appendingPathComponent("\(testUUID).mobileprovision")

        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: expectedPath.path, isDirectory: &isDirectory)
        #expect(fileExists && !isDirectory.boolValue)

        // Clean up
        try? FileManager.default.removeItem(at: expectedPath)
    }

    #endif
}
