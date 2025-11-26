import Foundation

#if os(macOS)
import Security

// swiftlint:disable deprecated_api
// Note: SecKeychain APIs are deprecated since macOS 10.10 but there is no modern replacement
// for programmatic keychain management required for CI/CD code signing workflows.
// We use these APIs intentionally as they are still functional and necessary.

/// Service for managing macOS Keychain operations
/// Handles certificate installation, temporary keychain creation for CI, and provisioning profile installation
public actor KeychainService {

    /// Imports a .p12 certificate into the specified keychain (or default if nil)
    /// - Parameters:
    ///   - p12Data: The PKCS#12 certificate data
    ///   - password: Password to decrypt the .p12 file
    ///   - keychain: Target keychain (nil for default)
    /// - Returns: The imported identity (certificate + private key)
    /// - Throws: MatchError.keychainImportFailed or MatchError.certificateInstallationFailed
    public func importCertificate(
        p12Data: Data,
        password: String,
        keychain: SecKeychain?
    ) async throws -> SecIdentity {
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password
        ]

        var items: CFArray?
        let status = SecPKCS12Import(
            p12Data as CFData,
            options as CFDictionary,
            &items
        )

        guard status == errSecSuccess else {
            throw MatchError.keychainImportFailed(
                "SecPKCS12Import failed with status: \(status) (\(secErrorString(status)))"
            )
        }

        guard let itemsArray = items as? [[String: Any]],
              let firstItem = itemsArray.first,
              let identity = firstItem[kSecImportItemIdentity as String] else {
            throw MatchError.keychainImportFailed("No identity found in imported certificate")
        }

        let secIdentity = identity as! SecIdentity

        // If a specific keychain is provided, we need to add the identity to it
        if let targetKeychain = keychain {
            try await addIdentityToKeychain(secIdentity, keychain: targetKeychain)
        }

        return secIdentity
    }

    /// Imports a .p12 certificate into the specified keychain, discarding the non-Sendable SecIdentity
    /// Use this method when you don't need to use the identity across actor boundaries
    /// - Parameters:
    ///   - p12Data: The PKCS#12 certificate data
    ///   - password: Password to decrypt the .p12 file
    ///   - keychain: Target keychain (nil for default)
    /// - Throws: MatchError.keychainImportFailed or MatchError.certificateInstallationFailed
    public func importCertificateDiscardingIdentity(
        p12Data: Data,
        password: String,
        keychain: SecKeychain?
    ) async throws {
        _ = try await importCertificate(p12Data: p12Data, password: password, keychain: keychain)
    }

    /// Creates a temporary keychain for CI environments
    /// - Parameter name: Name for the temporary keychain (without extension)
    /// - Returns: Tuple of (keychain reference, generated password)
    /// - Throws: MatchError.certificateInstallationFailed
    public func createTemporaryKeychain(name: String) async throws -> (SecKeychain, String) {
        let keychainPath = NSTemporaryDirectory()
            .appending(name)
            .appending(".keychain-db")

        // Generate a random password for the temporary keychain
        let password = UUID().uuidString

        var keychain: SecKeychain?
        let status = SecKeychainCreate(
            keychainPath,
            UInt32(password.utf8.count),
            password,
            false, // Don't prompt user
            nil,   // No initial access
            &keychain
        )

        guard status == errSecSuccess, let createdKeychain = keychain else {
            throw MatchError.certificateInstallationFailed(
                "Failed to create temporary keychain: \(status) (\(secErrorString(status)))"
            )
        }

        // Configure the keychain to not lock automatically
        var keychainSettings = SecKeychainSettings(
            version: UInt32(SEC_KEYCHAIN_SETTINGS_VERS1),
            lockOnSleep: false,
            useLockInterval: false,
            lockInterval: UInt32.max
        )

        SecKeychainSetSettings(createdKeychain, &keychainSettings)

        return (createdKeychain, password)
    }

    /// Deletes a temporary keychain
    /// - Parameter keychain: The keychain to delete
    /// - Throws: MatchError.certificateInstallationFailed
    public func deleteKeychain(_ keychain: SecKeychain) async throws {
        let status = SecKeychainDelete(keychain)

        guard status == errSecSuccess else {
            throw MatchError.certificateInstallationFailed(
                "Failed to delete keychain: \(status) (\(secErrorString(status)))"
            )
        }
    }

    /// Adds a keychain to the system search list
    /// - Parameter keychain: The keychain to add
    /// - Throws: MatchError.keychainImportFailed
    public func addToSearchList(_ keychain: SecKeychain) async throws {
        var searchList: CFArray?
        var status = SecKeychainCopySearchList(&searchList)

        guard status == errSecSuccess else {
            throw MatchError.keychainImportFailed(
                "Failed to get keychain search list: \(status) (\(secErrorString(status)))"
            )
        }

        var keychains = (searchList as? [SecKeychain]) ?? []

        // Only add if not already in the list
        let keychainPath = try getKeychainPath(keychain)
        let alreadyInList = keychains.contains { existingKeychain in
            guard let path = try? getKeychainPath(existingKeychain) else { return false }
            return path == keychainPath
        }

        if !alreadyInList {
            keychains.insert(keychain, at: 0) // Add at the beginning for priority
            status = SecKeychainSetSearchList(keychains as CFArray)

            guard status == errSecSuccess else {
                throw MatchError.keychainImportFailed(
                    "Failed to update keychain search list: \(status) (\(secErrorString(status)))"
                )
            }
        }
    }

    /// Installs a provisioning profile to ~/Library/MobileDevice/Provisioning Profiles/
    /// - Parameter profile: The provisioning profile to install
    /// - Throws: MatchError.profileInstallationFailed
    public func installProfile(_ profile: ProvisioningProfile) async throws {
        guard let content = profile.content else {
            throw MatchError.profileInstallationFailed(
                "Profile \(profile.name) has no content data"
            )
        }

        let profilesDirectory = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/MobileDevice/Provisioning Profiles")

        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(
            at: profilesDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let profilePath = profilesDirectory
            .appendingPathComponent("\(profile.uuid).mobileprovision")

        do {
            try content.write(to: profilePath, options: .atomic)
        } catch {
            throw MatchError.profileInstallationFailed(
                "Failed to write profile to \(profilePath.path): \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Private Helpers

    /// Adds an identity to a specific keychain
    private func addIdentityToKeychain(_ identity: SecIdentity, keychain: SecKeychain) async throws {
        // Extract certificate from identity
        var certificate: SecCertificate?
        var status = SecIdentityCopyCertificate(identity, &certificate)

        guard status == errSecSuccess, let cert = certificate else {
            throw MatchError.certificateInstallationFailed(
                "Failed to extract certificate from identity: \(status) (\(secErrorString(status)))"
            )
        }

        // Extract private key from identity
        var privateKey: SecKey?
        status = SecIdentityCopyPrivateKey(identity, &privateKey)

        guard status == errSecSuccess, let key = privateKey else {
            throw MatchError.certificateInstallationFailed(
                "Failed to extract private key from identity: \(status) (\(secErrorString(status)))"
            )
        }

        // Add certificate to keychain
        status = SecCertificateAddToKeychain(cert, keychain)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw MatchError.certificateInstallationFailed(
                "Failed to add certificate to keychain: \(status) (\(secErrorString(status)))"
            )
        }

        // Add private key to keychain
        let addKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecValueRef as String: key,
            kSecUseKeychain as String: keychain,
            kSecAttrLabel as String: "Imported Private Key"
        ]

        status = SecItemAdd(addKeyQuery as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw MatchError.certificateInstallationFailed(
                "Failed to add private key to keychain: \(status) (\(secErrorString(status)))"
            )
        }
    }

    /// Gets the file path for a keychain
    private func getKeychainPath(_ keychain: SecKeychain) throws -> String {
        var pathLength: UInt32 = 1024 // Max path length
        var pathBuffer = [CChar](repeating: 0, count: Int(pathLength))

        let status = SecKeychainGetPath(keychain, &pathLength, &pathBuffer)

        guard status == errSecSuccess else {
            throw MatchError.keychainImportFailed(
                "Failed to get keychain path: \(status)"
            )
        }

        // Convert CChar array to String by finding null terminator
        let nullIndex = pathBuffer.firstIndex(of: 0) ?? pathBuffer.endIndex
        return String(decoding: pathBuffer[..<nullIndex].map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// Converts Security framework error codes to human-readable strings
    private func secErrorString(_ status: OSStatus) -> String {
        if let errorString = SecCopyErrorMessageString(status, nil) as String? {
            return errorString
        }
        return "Unknown error"
    }
}

#else

// Linux stub implementation
// All Keychain operations throw platformNotSupported on Linux
// We use Never as return type for methods that would return non-Sendable types
// to avoid Swift 6 concurrency issues
public actor KeychainService {

    public func importCertificate(
        p12Data: Data,
        password: String,
        keychain: OpaquePointer? // SecKeychain not available on Linux
    ) async throws -> Never {
        throw MatchError.platformNotSupported("Keychain")
    }

    public func importCertificateDiscardingIdentity(
        p12Data: Data,
        password: String,
        keychain: OpaquePointer?
    ) async throws {
        throw MatchError.platformNotSupported("Keychain")
    }

    public func createTemporaryKeychain(name: String) async throws -> Never {
        throw MatchError.platformNotSupported("Keychain")
    }

    public func deleteKeychain(_ keychain: OpaquePointer?) async throws {
        throw MatchError.platformNotSupported("Keychain")
    }

    public func addToSearchList(_ keychain: OpaquePointer?) async throws {
        throw MatchError.platformNotSupported("Keychain")
    }

    public func installProfile(_ profile: ProvisioningProfile) async throws {
        throw MatchError.platformNotSupported("Keychain")
    }
}

#endif
