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
            "certs/development"
        case .distribution, .adhoc, .appstore:
            "certs/distribution"
        }
    }

    /// Profile directory name in Match storage
    public var profilePath: String {
        switch self {
        case .development:
            "profiles/development"
        case .distribution:
            "profiles/distribution"
        case .adhoc:
            "profiles/adhoc"
        case .appstore:
            "profiles/appstore"
        }
    }

    /// Apple certificate type identifier
    public var appleType: String {
        switch self {
        case .development:
            "IOS_DEVELOPMENT"
        case .distribution, .adhoc, .appstore:
            "IOS_DISTRIBUTION"
        }
    }

    /// Apple profile type identifier
    public var profileType: String {
        switch self {
        case .development:
            "IOS_APP_DEVELOPMENT"
        case .distribution:
            "IOS_APP_STORE"
        case .adhoc:
            "IOS_APP_ADHOC"
        case .appstore:
            "IOS_APP_STORE"
        }
    }
}
