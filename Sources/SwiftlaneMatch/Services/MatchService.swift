import Foundation
import Logging

/// Configuration for Match operations
public struct MatchConfiguration: Sendable {
    /// Git repository URL for certificate storage
    public let gitUrl: String

    /// Git branch name
    public let branch: String

    /// Team ID
    public let teamId: String

    /// App Store Connect API key ID
    public let apiKeyId: String?

    /// App Store Connect API issuer ID
    public let apiIssuerId: String?

    /// Path to App Store Connect API private key (.p8)
    public let apiKeyPath: String?

    /// Encryption password for certificates
    public let password: String

    /// Whether to run in readonly mode (don't create new certs)
    public let readonly: Bool

    /// Force regenerate profiles when new devices are added
    public let forceForNewDevices: Bool

    public init(
        gitUrl: String,
        branch: String = "master",
        teamId: String,
        apiKeyId: String? = nil,
        apiIssuerId: String? = nil,
        apiKeyPath: String? = nil,
        password: String,
        readonly: Bool = false,
        forceForNewDevices: Bool = false
    ) {
        self.gitUrl = gitUrl
        self.branch = branch
        self.teamId = teamId
        self.apiKeyId = apiKeyId
        self.apiIssuerId = apiIssuerId
        self.apiKeyPath = apiKeyPath
        self.password = password
        self.readonly = readonly
        self.forceForNewDevices = forceForNewDevices
    }

    /// Create configuration from environment variables
    public static func fromEnvironment() throws -> MatchConfiguration {
        guard let password = ProcessInfo.processInfo.environment["MATCH_PASSWORD"] else {
            throw MatchError.missingEnvironmentVariable("MATCH_PASSWORD")
        }

        guard let gitUrl = ProcessInfo.processInfo.environment["MATCH_GIT_URL"] else {
            throw MatchError.missingEnvironmentVariable("MATCH_GIT_URL")
        }

        let teamId = ProcessInfo.processInfo.environment["MATCH_TEAM_ID"] ?? ""

        return MatchConfiguration(
            gitUrl: gitUrl,
            branch: ProcessInfo.processInfo.environment["MATCH_GIT_BRANCH"] ?? "master",
            teamId: teamId,
            apiKeyId: ProcessInfo.processInfo.environment["APP_STORE_CONNECT_API_KEY_ID"],
            apiIssuerId: ProcessInfo.processInfo.environment["APP_STORE_CONNECT_API_ISSUER_ID"],
            apiKeyPath: ProcessInfo.processInfo.environment["APP_STORE_CONNECT_API_KEY_PATH"],
            password: password,
            readonly: ProcessInfo.processInfo.environment["MATCH_READONLY"] == "true",
            forceForNewDevices: ProcessInfo.processInfo.environment["MATCH_FORCE_FOR_NEW_DEVICES"] == "true"
        )
    }
}

/// Result of a sync operation
public struct SyncResult: Sendable {
    /// Installed certificates
    public let certificates: [Certificate]

    /// Installed provisioning profiles
    public let profiles: [ProvisioningProfile]

    public init(certificates: [Certificate], profiles: [ProvisioningProfile]) {
        self.certificates = certificates
        self.profiles = profiles
    }
}

/// Result of a nuke operation
public struct NukeResult: Sendable {
    /// Number of certificates revoked
    public let certificatesRevoked: Int

    /// Number of profiles deleted
    public let profilesDeleted: Int

    public init(certificatesRevoked: Int, profilesDeleted: Int) {
        self.certificatesRevoked = certificatesRevoked
        self.profilesDeleted = profilesDeleted
    }
}

/// Result of device registration
public struct RegisterDevicesResult: Sendable {
    /// Newly registered devices
    public let registered: [Device]

    /// Devices that were already registered
    public let existing: [Device]

    public init(registered: [Device], existing: [Device]) {
        self.registered = registered
        self.existing = existing
    }
}

/// Main orchestrator for Match operations
public actor MatchService {
    private let configuration: MatchConfiguration
    private let storage: GitStorage
    private let crypto: CryptoService
    private let keychain: KeychainService
    private let api: AppStoreConnectAPI?
    private let logger: Logger

    /// Local path where repository is cloned
    private var localRepoPath: URL?

    public init(configuration: MatchConfiguration) throws {
        self.configuration = configuration
        self.storage = GitStorage(gitUrl: configuration.gitUrl, branch: configuration.branch)
        self.crypto = CryptoService()
        self.keychain = KeychainService()
        self.logger = Logger(label: "swiftlane.match")

        // Initialize API client if credentials provided
        if let keyId = configuration.apiKeyId,
           let issuerId = configuration.apiIssuerId,
           let keyPath = configuration.apiKeyPath {
            self.api = try AppStoreConnectAPI(
                keyId: keyId,
                issuerId: issuerId,
                privateKeyPath: keyPath
            )
        } else {
            self.api = nil
        }
    }

    /// Shuts down the service and releases resources.
    /// Call this when done using the MatchService to properly close HTTP connections.
    public func shutdown() async throws {
        try await api?.shutdown()
    }

    // MARK: - Sync Operation

    /// Synchronize certificates and profiles from storage
    public func sync(
        type: CertificateType,
        appIdentifiers: [String] = []
    ) async throws -> SyncResult {
        logger.info("Starting sync for \(type.rawValue) certificates")

        // Download repository
        let repoPath = try await downloadRepository()

        // Find and decrypt certificates
        let certificates = try await syncCertificates(type: type, repoPath: repoPath)

        // Find and install profiles
        var profiles: [ProvisioningProfile] = []
        if appIdentifiers.isEmpty {
            // Sync all profiles of this type
            profiles = try await syncProfiles(type: type, repoPath: repoPath)
        } else {
            // Sync profiles for specific app identifiers
            for appId in appIdentifiers {
                let appProfiles = try await syncProfiles(type: type, appIdentifier: appId, repoPath: repoPath)
                profiles.append(contentsOf: appProfiles)
            }
        }

        logger.info("Sync complete: \(certificates.count) certificates, \(profiles.count) profiles")
        return SyncResult(certificates: certificates, profiles: profiles)
    }

    private func syncCertificates(type: CertificateType, repoPath: URL) async throws -> [Certificate] {
        let certPath = repoPath.appendingPathComponent(type.storagePath)

        guard Foundation.FileManager.default.directoryExists(atPath: certPath.path) else {
            if configuration.readonly {
                throw MatchError.noCertificatesFound(type)
            }
            // Create new certificate if API is available
            return try await createAndStoreCertificate(type: type, repoPath: repoPath)
        }

        // Find all .p12 files
        let p12Files = try Foundation.FileManager.default.contentsOfDirectory(at: certPath, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "p12" }

        if p12Files.isEmpty {
            if configuration.readonly {
                throw MatchError.noCertificatesFound(type)
            }
            return try await createAndStoreCertificate(type: type, repoPath: repoPath)
        }

        var installedCerts: [Certificate] = []

        for p12File in p12Files {
            let encryptedData = try Data(contentsOf: p12File)
            let decryptedData = try await crypto.decrypt(data: encryptedData, password: configuration.password)

            // Install to keychain (discarding non-Sendable SecIdentity result)
            #if os(macOS)
            try await keychain.importCertificateDiscardingIdentity(p12Data: decryptedData, password: configuration.password, keychain: nil)
            #endif

            // Create certificate model (simplified - actual impl would parse the p12)
            let cert = Certificate(
                id: p12File.deletingPathExtension().lastPathComponent,
                serialNumber: "imported",
                name: p12File.deletingPathExtension().lastPathComponent,
                type: type,
                teamId: configuration.teamId,
                expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60)
            )
            installedCerts.append(cert)
            logger.info("Installed certificate: \(cert.name)")
        }

        return installedCerts
    }

    private func syncProfiles(type: CertificateType, appIdentifier: String? = nil, repoPath: URL) async throws -> [ProvisioningProfile] {
        let profilePath = repoPath.appendingPathComponent(type.profilePath)

        guard Foundation.FileManager.default.directoryExists(atPath: profilePath.path) else {
            if configuration.readonly {
                throw MatchError.noProfilesFound(type, appIdentifier ?? "*")
            }
            return []
        }

        // Find all .mobileprovision files
        var profileFiles = try Foundation.FileManager.default.contentsOfDirectory(at: profilePath, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "mobileprovision" }

        // Filter by app identifier if specified
        if let appId = appIdentifier {
            profileFiles = profileFiles.filter { $0.lastPathComponent.contains(appId.replacingOccurrences(of: ".", with: "_")) }
        }

        var installedProfiles: [ProvisioningProfile] = []

        for profileFile in profileFiles {
            let encryptedData = try Data(contentsOf: profileFile)
            let decryptedData = try await crypto.decrypt(data: encryptedData, password: configuration.password)

            // Parse profile to get UUID (simplified)
            let uuid = profileFile.deletingPathExtension().lastPathComponent

            let profile = ProvisioningProfile(
                id: uuid,
                uuid: uuid,
                name: profileFile.deletingPathExtension().lastPathComponent,
                bundleId: appIdentifier ?? "*",
                type: type,
                teamId: configuration.teamId,
                teamName: "",
                expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60),
                content: decryptedData
            )

            // Install profile
            try await keychain.installProfile(profile)
            installedProfiles.append(profile)
            logger.info("Installed profile: \(profile.name)")
        }

        return installedProfiles
    }

    private func createAndStoreCertificate(type: CertificateType, repoPath: URL) async throws -> [Certificate] {
        guard let api = api else {
            throw MatchError.missingConfiguration("App Store Connect API credentials required to create certificates")
        }

        logger.info("Creating new \(type.rawValue) certificate")

        // Generate CSR (simplified - actual impl would use Security framework)
        let csrContent = "-----BEGIN CERTIFICATE REQUEST-----\n...\n-----END CERTIFICATE REQUEST-----"

        let cert = try await api.createCertificate(type: type, csrContent: csrContent)

        // Store encrypted certificate
        let certPath = repoPath.appendingPathComponent(type.storagePath)
        try Foundation.FileManager.default.createDirectory(at: certPath, withIntermediateDirectories: true)

        if let content = cert.content {
            let encrypted = try await crypto.encrypt(data: content, password: configuration.password)
            let p12Path = certPath.appendingPathComponent("\(cert.id).p12")
            try encrypted.write(to: p12Path)

            // Push to repository
            try await storage.upload(from: repoPath, message: "Add \(type.rawValue) certificate")
        }

        return [cert]
    }

    // MARK: - Nuke Operation

    /// Revoke and remove all certificates of a type
    public func nuke(type: CertificateType) async throws -> NukeResult {
        guard let api = api else {
            throw MatchError.missingConfiguration("App Store Connect API credentials required for nuke operation")
        }

        logger.warning("Starting nuke operation for \(type.rawValue) certificates")

        // Get all certificates of this type
        let certificates = try await api.listCertificates(type: type)
        var revokedCount = 0

        for cert in certificates {
            do {
                try await api.revokeCertificate(id: cert.id)
                revokedCount += 1
                logger.info("Revoked certificate: \(cert.name)")
            } catch {
                logger.error("Failed to revoke certificate \(cert.name): \(error)")
            }
        }

        // Get all profiles of this type
        let profiles = try await api.listProfiles(type: type, bundleId: nil)
        var deletedCount = 0

        for profile in profiles {
            do {
                try await api.deleteProfile(id: profile.id)
                deletedCount += 1
                logger.info("Deleted profile: \(profile.name)")
            } catch {
                logger.error("Failed to delete profile \(profile.name): \(error)")
            }
        }

        // Remove from Git storage
        let repoPath = try await downloadRepository()
        let certPath = repoPath.appendingPathComponent(type.storagePath)
        let profilePath = repoPath.appendingPathComponent(type.profilePath)

        if Foundation.FileManager.default.directoryExists(atPath: certPath.path) {
            try Foundation.FileManager.default.removeItem(at: certPath)
        }
        if Foundation.FileManager.default.directoryExists(atPath: profilePath.path) {
            try Foundation.FileManager.default.removeItem(at: profilePath)
        }

        try await storage.upload(from: repoPath, message: "Nuke \(type.rawValue) certificates and profiles")

        logger.warning("Nuke complete: \(revokedCount) certificates revoked, \(deletedCount) profiles deleted")
        return NukeResult(certificatesRevoked: revokedCount, profilesDeleted: deletedCount)
    }

    // MARK: - Register Devices

    /// Register devices from a file
    public func registerDevices(fromFile path: String, platform: Device.Platform = .iOS) async throws -> RegisterDevicesResult {
        let fileURL = URL(fileURLWithPath: path)
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        var devices: [(name: String, udid: String)] = []

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // Format: "Device Name\tUDID" or "UDID\tDevice Name"
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

        return try await registerDevices(devices, platform: platform)
    }

    /// Register devices from a dictionary
    public func registerDevices(_ devices: [(name: String, udid: String)], platform: Device.Platform = .iOS) async throws -> RegisterDevicesResult {
        guard let api = api else {
            throw MatchError.missingConfiguration("App Store Connect API credentials required to register devices")
        }

        logger.info("Registering \(devices.count) devices")

        // Get existing devices
        let existingDevices = try await api.listDevices(platform: platform)
        let existingUDIDs = Set(existingDevices.map { $0.udid.lowercased() })

        var registered: [Device] = []
        var existing: [Device] = []

        for device in devices {
            if existingUDIDs.contains(device.udid.lowercased()) {
                if let existingDevice = existingDevices.first(where: { $0.udid.lowercased() == device.udid.lowercased() }) {
                    existing.append(existingDevice)
                }
                logger.info("Device already registered: \(device.name)")
            } else {
                let newDevice = try await api.registerDevice(name: device.name, udid: device.udid, platform: platform)
                registered.append(newDevice)
                logger.info("Registered device: \(device.name)")
            }
        }

        logger.info("Registration complete: \(registered.count) new, \(existing.count) existing")
        return RegisterDevicesResult(registered: registered, existing: existing)
    }

    // MARK: - Change Password

    /// Re-encrypt all files with a new password
    public func changePassword(from oldPassword: String, to newPassword: String) async throws {
        logger.info("Changing encryption password")

        let repoPath = try await downloadRepository()

        // Find all encrypted files
        let enumerator = Foundation.FileManager.default.enumerator(at: repoPath, includingPropertiesForKeys: nil)
        var filesToReencrypt: [URL] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "p12" || fileURL.pathExtension == "mobileprovision" {
                filesToReencrypt.append(fileURL)
            }
        }

        logger.info("Re-encrypting \(filesToReencrypt.count) files")

        for fileURL in filesToReencrypt {
            let encryptedData = try Data(contentsOf: fileURL)
            let decryptedData = try await crypto.decrypt(data: encryptedData, password: oldPassword)
            let reencryptedData = try await crypto.encrypt(data: decryptedData, password: newPassword)
            try reencryptedData.write(to: fileURL)
        }

        try await storage.upload(from: repoPath, message: "Change encryption password")
        logger.info("Password changed successfully")
    }

    // MARK: - Helpers

    private func downloadRepository() async throws -> URL {
        if let path = localRepoPath, Foundation.FileManager.default.directoryExists(atPath: path.path) {
            return path
        }

        let tempDir = Foundation.FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftlane-match-\(UUID().uuidString)")

        try await storage.download(to: tempDir)
        localRepoPath = tempDir
        return tempDir
    }
}
