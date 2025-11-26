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
        case .encryptionFailed(let reason):
            return "Encryption failed: \(reason)"
        case .decryptionFailed(let reason):
            return "Decryption failed: \(reason)"
        case .invalidPassword:
            return "Invalid password - decryption failed"
        case .keyDerivationFailed:
            return "Failed to derive encryption key from password"

        case .gitCloneFailed(let reason):
            return "Failed to clone Git repository: \(reason)"
        case .gitPushFailed(let reason):
            return "Failed to push to Git repository: \(reason)"
        case .gitAuthenticationFailed:
            return "Git authentication failed"
        case .storageNotConfigured:
            return "Storage not configured - set MATCH_GIT_URL or provide gitUrl"
        case .fileNotFound(let path):
            return "File not found: \(path)"

        case .keychainAccessDenied:
            return "Keychain access denied"
        case .keychainImportFailed(let reason):
            return "Failed to import to Keychain: \(reason)"
        case .keychainNotAvailable:
            return "Keychain operations require macOS"
        case .certificateInstallationFailed(let reason):
            return "Certificate installation failed: \(reason)"
        case .profileInstallationFailed(let reason):
            return "Profile installation failed: \(reason)"

        case .apiAuthenticationFailed:
            return "App Store Connect API authentication failed"
        case .apiRequestFailed(let reason):
            return "App Store Connect API request failed: \(reason)"
        case .certificateCreationFailed(let reason):
            return "Failed to create certificate: \(reason)"
        case .certificateRevocationFailed(let reason):
            return "Failed to revoke certificate: \(reason)"
        case .profileCreationFailed(let reason):
            return "Failed to create provisioning profile: \(reason)"
        case .profileDeletionFailed(let reason):
            return "Failed to delete provisioning profile: \(reason)"
        case .deviceRegistrationFailed(let reason):
            return "Failed to register device: \(reason)"

        case .missingConfiguration(let key):
            return "Missing configuration: \(key)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .missingEnvironmentVariable(let name):
            return "Required environment variable not set: \(name)"

        case .noCertificatesFound(let type):
            return "No \(type.rawValue) certificates found in storage"
        case .noProfilesFound(let type, let bundleId):
            return "No \(type.rawValue) profiles found for \(bundleId)"
        case .readonlyModeViolation:
            return "Cannot create certificates/profiles in readonly mode"
        case .operationCancelled:
            return "Operation cancelled by user"
        case .platformNotSupported(let operation):
            return "\(operation) is not supported on this platform"
        }
    }
}
