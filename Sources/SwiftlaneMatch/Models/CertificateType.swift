import Foundation

/// Certificate type for code signing
public enum CertificateType: String, Sendable, CaseIterable, Codable {
    case development
    case distribution
    case adhoc
    case appstore

    /// The directory name used in Match storage
    public var storagePath: String {
        switch self {
        case .development:
            return "certs/development"
        case .distribution, .adhoc, .appstore:
            return "certs/distribution"
        }
    }

    /// Profile directory name in Match storage
    public var profilePath: String {
        switch self {
        case .development:
            return "profiles/development"
        case .distribution:
            return "profiles/distribution"
        case .adhoc:
            return "profiles/adhoc"
        case .appstore:
            return "profiles/appstore"
        }
    }

    /// Apple certificate type identifier
    public var appleType: String {
        switch self {
        case .development:
            return "IOS_DEVELOPMENT"
        case .distribution, .adhoc, .appstore:
            return "IOS_DISTRIBUTION"
        }
    }

    /// Apple profile type identifier
    public var profileType: String {
        switch self {
        case .development:
            return "IOS_APP_DEVELOPMENT"
        case .distribution:
            return "IOS_APP_STORE"
        case .adhoc:
            return "IOS_APP_ADHOC"
        case .appstore:
            return "IOS_APP_STORE"
        }
    }
}
