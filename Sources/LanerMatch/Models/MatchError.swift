import Foundation

/// Errors that can occur during Match operations
public enum MatchError: Error, LocalizedError, Sendable, Equatable {
    // Crypto errors
    case encryptionFailed(String)
    case decryptionFailed(String)
    case invalidPassword
    case keyDerivationFailed

    // Storage errors
    case gitCloneFailed(String)
    case gitPushFailed(String)
    case gitAuthenticationFailed
    case storageNotConfigured
    case fileNotFound(String)

    // Keychain errors
    case keychainAccessDenied
    case keychainImportFailed(String)
    case keychainNotAvailable
    case certificateInstallationFailed(String)
    case profileInstallationFailed(String)

    // App Store Connect errors
    case apiAuthenticationFailed
    case apiRequestFailed(String)
    case certificateCreationFailed(String)
    case certificateRevocationFailed(String)
    case profileCreationFailed(String)
    case profileDeletionFailed(String)
    case deviceRegistrationFailed(String)

    // Configuration errors
    case missingConfiguration(String)
    case invalidConfiguration(String)
    case missingEnvironmentVariable(String)

    // Operation errors
    case noCertificatesFound(CertificateType)
    case noProfilesFound(CertificateType, String)
    case readonlyModeViolation
    case operationCancelled
    case platformNotSupported(String)

    public var errorDescription: String? {
        switch self {
        case let .encryptionFailed(reason):
            "Encryption failed: \(reason)"
        case let .decryptionFailed(reason):
            "Decryption failed: \(reason)"
        case .invalidPassword:
            "Invalid password - decryption failed"
        case .keyDerivationFailed:
            "Failed to derive encryption key from password"
        case let .gitCloneFailed(reason):
            "Failed to clone Git repository: \(reason)"
        case let .gitPushFailed(reason):
            "Failed to push to Git repository: \(reason)"
        case .gitAuthenticationFailed:
            "Git authentication failed"
        case .storageNotConfigured:
            "Storage not configured - set MATCH_GIT_URL or provide gitUrl"
        case let .fileNotFound(path):
            "File not found: \(path)"
        case .keychainAccessDenied:
            "Keychain access denied"
        case let .keychainImportFailed(reason):
            "Failed to import to Keychain: \(reason)"
        case .keychainNotAvailable:
            "Keychain operations require macOS"
        case let .certificateInstallationFailed(reason):
            "Certificate installation failed: \(reason)"
        case let .profileInstallationFailed(reason):
            "Profile installation failed: \(reason)"
        case .apiAuthenticationFailed:
            "App Store Connect API authentication failed"
        case let .apiRequestFailed(reason):
            "App Store Connect API request failed: \(reason)"
        case let .certificateCreationFailed(reason):
            "Failed to create certificate: \(reason)"
        case let .certificateRevocationFailed(reason):
            "Failed to revoke certificate: \(reason)"
        case let .profileCreationFailed(reason):
            "Failed to create provisioning profile: \(reason)"
        case let .profileDeletionFailed(reason):
            "Failed to delete provisioning profile: \(reason)"
        case let .deviceRegistrationFailed(reason):
            "Failed to register device: \(reason)"
        case let .missingConfiguration(key):
            "Missing configuration: \(key)"
        case let .invalidConfiguration(reason):
            "Invalid configuration: \(reason)"
        case let .missingEnvironmentVariable(name):
            "Required environment variable not set: \(name)"
        case let .noCertificatesFound(type):
            "No \(type.rawValue) certificates found in storage"
        case let .noProfilesFound(type, bundleId):
            "No \(type.rawValue) profiles found for \(bundleId)"
        case .readonlyModeViolation:
            "Cannot create certificates/profiles in readonly mode"
        case .operationCancelled:
            "Operation cancelled by user"
        case let .platformNotSupported(operation):
            "\(operation) is not supported on this platform"
        }
    }
}
