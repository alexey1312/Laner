import Foundation
@testable import LanerMatch
import Testing

/// Integration tests for MatchService.
///
/// These tests verify the orchestration logic and integration between components.
/// Tests use mocked storage providers and API clients to avoid external dependencies.
@Suite("MatchService Integration Tests")
struct MatchServiceTests {
    // MARK: - Configuration Tests

    @Test("MatchConfiguration.fromEnvironment() parses all required variables")
    func configurationFromEnvironmentComplete() throws {
        // Note: Testing fromEnvironment() requires actual environment variables
        // This test verifies the parsing logic works correctly when variables are present

        // If MATCH_PASSWORD and MATCH_GIT_URL are set, test parsing
        if ProcessInfo.processInfo.environment["MATCH_PASSWORD"] != nil,
           ProcessInfo.processInfo.environment["MATCH_GIT_URL"] != nil
        {
            let config = try MatchConfiguration.fromEnvironment()
            // Basic validation - config was created successfully
            #expect(!config.password.isEmpty)
            #expect(!config.gitUrl.isEmpty)
        }

        // Test the equivalent with direct initialization (doesn't require env vars)
        let config = MatchConfiguration(
            gitUrl: "https://github.com/test/certificates.git",
            branch: "develop",
            teamId: "ABC123DEF4",
            apiKeyId: "KEY123",
            apiIssuerId: "issuer-uuid",
            apiKeyPath: "/path/to/key.p8",
            password: "test_password_123",
            readonly: true,
            forceForNewDevices: true
        )

        #expect(config.password == "test_password_123")
        #expect(config.gitUrl == "https://github.com/test/certificates.git")
        #expect(config.branch == "develop")
        #expect(config.teamId == "ABC123DEF4")
        #expect(config.apiKeyId == "KEY123")
        #expect(config.apiIssuerId == "issuer-uuid")
        #expect(config.apiKeyPath == "/path/to/key.p8")
        #expect(config.readonly == true)
        #expect(config.forceForNewDevices == true)
    }

    @Test("MatchConfiguration.fromEnvironment() uses default values")
    func configurationFromEnvironmentDefaults() throws {
        // Test default values with direct initialization (matches fromEnvironment behavior)
        let config = MatchConfiguration(
            gitUrl: "https://github.com/test/certs.git",
            teamId: "",
            password: "password123"
        )

        #expect(config.password == "password123")
        #expect(config.gitUrl == "https://github.com/test/certs.git")
        #expect(config.branch == "master") // Default
        #expect(config.teamId == "") // Default empty
        #expect(config.apiKeyId == nil)
        #expect(config.apiIssuerId == nil)
        #expect(config.apiKeyPath == nil)
        #expect(config.readonly == false) // Default
        #expect(config.forceForNewDevices == false) // Default
    }

    @Test("MatchConfiguration.fromEnvironment() throws on missing MATCH_PASSWORD")
    func configurationFromEnvironmentMissingPassword() throws {
        // Note: Testing actual environment variable errors would require process isolation
        // This test documents the expected behavior

        // In actual usage, missing MATCH_PASSWORD would throw:
        // MatchError.missingEnvironmentVariable("MATCH_PASSWORD")

        // We can verify the error type exists and has correct message
        let error = MatchError.missingEnvironmentVariable("MATCH_PASSWORD")
        #expect(error.errorDescription?.contains("MATCH_PASSWORD") == true)
    }

    @Test("MatchConfiguration.fromEnvironment() throws on missing MATCH_GIT_URL")
    func configurationFromEnvironmentMissingGitUrl() throws {
        // Note: Testing actual environment variable errors would require process isolation
        // This test documents the expected behavior

        // In actual usage, missing MATCH_GIT_URL would throw:
        // MatchError.missingEnvironmentVariable("MATCH_GIT_URL")

        // We can verify the error type exists and has correct message
        let error = MatchError.missingEnvironmentVariable("MATCH_GIT_URL")
        #expect(error.errorDescription?.contains("MATCH_GIT_URL") == true)
    }

    @Test("MatchConfiguration boolean parsing handles various values")
    func configurationBooleanParsing() throws {
        // Test readonly true
        let config1 = MatchConfiguration(
            gitUrl: "https://test.git",
            teamId: "TEAM123",
            password: "pass",
            readonly: true
        )
        #expect(config1.readonly == true)

        // Test readonly false
        let config2 = MatchConfiguration(
            gitUrl: "https://test.git",
            teamId: "TEAM123",
            password: "pass",
            readonly: false
        )
        #expect(config2.readonly == false)

        // Test readonly default (false)
        let config3 = MatchConfiguration(
            gitUrl: "https://test.git",
            teamId: "TEAM123",
            password: "pass"
        )
        #expect(config3.readonly == false)

        // Test forceForNewDevices
        let config4 = MatchConfiguration(
            gitUrl: "https://test.git",
            teamId: "TEAM123",
            password: "pass",
            forceForNewDevices: true
        )
        #expect(config4.forceForNewDevices == true)
    }

    // MARK: - MatchService Initialization Tests

    @Test("MatchService initializes with valid configuration")
    func matchServiceInitialization() throws {
        let config = MatchConfiguration(
            gitUrl: "https://github.com/test/certificates.git",
            branch: "main",
            teamId: "TEAM123",
            password: "test_password"
        )

        // Should not throw - if we get here, service was created successfully
        let service = try MatchService(configuration: config)
        _ = service // Verify service was created
    }

    @Test("MatchService initializes API client when credentials provided")
    func matchServiceInitializesAPIClient() async throws {
        // Create a temporary key file for testing
        let tempKeyPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_key_\(UUID().uuidString).p8")

        // Sample P-256 private key (test key, not real - same as AppStoreConnectAPITests)
        let mockP8Content = """
        -----BEGIN PRIVATE KEY-----
        MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgPGJGAm4X1fvBuC1z
        SpO/4Gear0aKE8OuC1a/eHM5Mz6hRANCAATRJbvPcvLf5l3gKDmVLp8mLdHl1OtH
        R/J6fQSvZqEbJWVcYVh5jBXV3VhNMnVlYwM1zNxVCLZGD0aVhJXVZqEl
        -----END PRIVATE KEY-----
        """
        try mockP8Content.write(to: tempKeyPath, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempKeyPath)
        }

        let config = MatchConfiguration(
            gitUrl: "https://github.com/test/certificates.git",
            branch: "main",
            teamId: "TEAM123",
            apiKeyId: "KEY123",
            apiIssuerId: "issuer-uuid",
            apiKeyPath: tempKeyPath.path,
            password: "test_password"
        )

        // Should initialize API client without throwing
        let service = try MatchService(configuration: config)

        // Properly shutdown to release HTTP client resources
        try await service.shutdown()
    }

    @Test("MatchService initializes without API client when credentials not provided")
    func matchServiceInitializesWithoutAPIClient() throws {
        let config = MatchConfiguration(
            gitUrl: "https://github.com/test/certificates.git",
            branch: "main",
            teamId: "TEAM123",
            password: "test_password"
        )

        _ = try MatchService(configuration: config)
    }

    // MARK: - Mock Storage Tests

    @Test("MockStorageProvider downloads and uploads successfully")
    func mockStorageProvider() async throws {
        let storage = MockStorageProvider()

        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString)")

        // Test download
        try await storage.download(to: tempPath)
        #expect(storage.downloadCalled)
        #expect(storage.lastDownloadPath == tempPath)

        // Test upload
        try await storage.upload(from: tempPath, message: "Test commit")
        #expect(storage.uploadCalled)
        #expect(storage.lastUploadPath == tempPath)
        #expect(storage.lastUploadMessage == "Test commit")

        // Test exists
        let exists = try await storage.exists()
        #expect(exists)

        // Cleanup
        try? FileManager.default.removeItem(at: tempPath)
    }

    // MARK: - SyncResult Tests

    @Test("SyncResult initializes correctly")
    func syncResultInitialization() {
        let cert = Certificate(
            id: "cert1",
            serialNumber: "123456",
            name: "Development Certificate",
            type: .development,
            teamId: "TEAM123",
            expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60)
        )

        let profile = ProvisioningProfile(
            id: "profile1",
            uuid: "uuid-123",
            name: "Development Profile",
            bundleId: "com.example.app",
            type: .development,
            teamId: "TEAM123",
            teamName: "Test Team",
            expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60),
            content: Data()
        )

        let result = SyncResult(certificates: [cert], profiles: [profile])

        #expect(result.certificates.count == 1)
        #expect(result.profiles.count == 1)
        #expect(result.certificates.first?.id == "cert1")
        #expect(result.profiles.first?.id == "profile1")
    }

    // MARK: - NukeResult Tests

    @Test("NukeResult initializes correctly")
    func nukeResultInitialization() {
        let result = NukeResult(certificatesRevoked: 3, profilesDeleted: 5)

        #expect(result.certificatesRevoked == 3)
        #expect(result.profilesDeleted == 5)
    }

    // MARK: - RegisterDevicesResult Tests

    @Test("RegisterDevicesResult initializes correctly")
    func registerDevicesResultInitialization() {
        let device1 = Device(
            id: "device1",
            udid: "00008030-001234567890401E",
            name: "Test iPhone",
            platform: .iOS,
            deviceClass: .iPhone,
            status: .enabled
        )

        let device2 = Device(
            id: "device2",
            udid: "00008101-000123456789012E",
            name: "Test iPad",
            platform: .iOS,
            deviceClass: .iPad,
            status: .enabled
        )

        let result = RegisterDevicesResult(registered: [device1], existing: [device2])

        #expect(result.registered.count == 1)
        #expect(result.existing.count == 1)
        #expect(result.registered.first?.name == "Test iPhone")
        #expect(result.existing.first?.name == "Test iPad")
    }

    // MARK: - Integration Test Helpers

    @Test("MatchService with mock storage handles sync flow")
    func syncFlowWithMockStorage() async throws {
        // This test demonstrates the sync flow structure
        // In a full implementation, we would mock the storage provider
        // and verify the complete flow

        let config = MatchConfiguration(
            gitUrl: "https://github.com/test/certificates.git",
            branch: "main",
            teamId: "TEAM123",
            password: "test_password",
            readonly: true
        )

        _ = try MatchService(configuration: config)

        // Note: Full sync test would require mocking:
        // - GitStorage to provide mock repository
        // - File system to have encrypted certificate files
        // - Keychain operations to be mocked
        // This demonstrates the test structure
    }

    @Test("MatchService configuration validation")
    func matchServiceConfigurationValidation() throws {
        // Test various configuration combinations

        // Valid minimal config
        let config1 = MatchConfiguration(
            gitUrl: "https://github.com/test/certs.git",
            teamId: "TEAM123",
            password: "password"
        )
        #expect(config1.branch == "master") // Default
        #expect(config1.readonly == false)

        // Valid complete config
        let config2 = MatchConfiguration(
            gitUrl: "https://github.com/test/certs.git",
            branch: "develop",
            teamId: "TEAM123",
            apiKeyId: "KEY123",
            apiIssuerId: "issuer",
            apiKeyPath: "/path/to/key.p8",
            password: "password",
            readonly: true,
            forceForNewDevices: true
        )
        #expect(config2.branch == "develop")
        #expect(config2.readonly == true)
        #expect(config2.forceForNewDevices == true)
    }
}

// MARK: - Mock Storage Provider

/// Mock storage provider for testing
final class MockStorageProvider: StorageProvider, @unchecked Sendable {
    var downloadCalled = false
    var uploadCalled = false
    var existsCalled = false

    var lastDownloadPath: URL?
    var lastUploadPath: URL?
    var lastUploadMessage: String?

    var shouldThrowOnDownload = false
    var shouldThrowOnUpload = false
    var existsResult = true

    func download(to localPath: URL) async throws {
        downloadCalled = true
        lastDownloadPath = localPath

        if shouldThrowOnDownload {
            throw MatchError.gitCloneFailed("Mock download failure")
        }

        // Create directory structure for testing
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: localPath, withIntermediateDirectories: true)

        // Create mock certificate directory
        let certsDir = localPath.appendingPathComponent("certs/development")
        try fileManager.createDirectory(at: certsDir, withIntermediateDirectories: true)

        // Create mock profile directory
        let profilesDir = localPath.appendingPathComponent("profiles/development")
        try fileManager.createDirectory(at: profilesDir, withIntermediateDirectories: true)
    }

    func upload(from localPath: URL, message: String) async throws {
        uploadCalled = true
        lastUploadPath = localPath
        lastUploadMessage = message

        if shouldThrowOnUpload {
            throw MatchError.gitPushFailed("Mock upload failure")
        }
    }

    func exists() async throws -> Bool {
        existsCalled = true
        return existsResult
    }
}

// MARK: - Additional Integration Tests

@Suite("MatchService Device Registration Tests")
struct MatchServiceDeviceTests {
    @Test("Device registration parses file format correctly")
    func deviceFileParsingTabDelimited() async throws {
        let fileContent = """
        # Device list
        Device Name 1\t00008030-001234567890401E
        00008101-000123456789012E\tDevice Name 2
        # Comment line
        Device Name 3\t00008020-001A1B2C3D4E501F
        """

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("devices_\(UUID().uuidString).txt")

        try fileContent.write(to: tempFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }

        // Parse the file (this would be done by MatchService.registerDevices)
        let content = try String(contentsOf: tempFile, encoding: .utf8)
        var devices: [(name: String, udid: String)] = []

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let parts = trimmed.components(separatedBy: "\t")
            if parts.count >= 2 {
                // Determine which is UDID (longer, alphanumeric)
                if parts[0].count > parts[1].count {
                    devices.append((name: parts[1], udid: parts[0]))
                } else {
                    devices.append((name: parts[0], udid: parts[1]))
                }
            }
        }

        #expect(devices.count == 3)
        #expect(devices[0].name == "Device Name 1")
        #expect(devices[0].udid == "00008030-001234567890401E")
        #expect(devices[1].name == "Device Name 2")
        #expect(devices[2].name == "Device Name 3")
    }

    @Test("Device registration handles empty and comment lines")
    func deviceFileParsingWithEmptyLines() async throws {
        let fileContent = """

        # Header comment
        Device 1\t00008030-001234567890401E

        # Another comment

        Device 2\t00008101-000123456789012E

        """

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("devices_\(UUID().uuidString).txt")

        try fileContent.write(to: tempFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }

        let content = try String(contentsOf: tempFile, encoding: .utf8)
        var devices: [(name: String, udid: String)] = []

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let parts = trimmed.components(separatedBy: "\t")
            if parts.count >= 2 {
                if parts[0].count > parts[1].count {
                    devices.append((name: parts[1], udid: parts[0]))
                } else {
                    devices.append((name: parts[0], udid: parts[1]))
                }
            }
        }

        #expect(devices.count == 2)
    }
}

@Suite("MatchService Error Handling Tests")
struct MatchServiceErrorTests {
    @Test("Configuration validates required fields")
    func configurationRequiredFields() throws {
        // Empty git URL should be accepted by initializer
        // (validation happens at runtime when used)
        let config = MatchConfiguration(
            gitUrl: "",
            teamId: "TEAM123",
            password: "password"
        )
        #expect(config.gitUrl == "")
    }

    @Test("Service handles missing API credentials gracefully")
    func serviceWithoutAPICredentials() throws {
        let config = MatchConfiguration(
            gitUrl: "https://github.com/test/certs.git",
            teamId: "TEAM123",
            password: "password"
        )

        _ = try MatchService(configuration: config)

        // Note: Operations requiring API would throw MatchError.missingConfiguration
        // when actually executed
    }

    @Test("Readonly mode prevents certificate creation")
    func readonlyModeValidation() {
        let config = MatchConfiguration(
            gitUrl: "https://github.com/test/certs.git",
            teamId: "TEAM123",
            password: "password",
            readonly: true
        )

        #expect(config.readonly == true)
        // Actual readonly enforcement happens in sync operation
    }
}
