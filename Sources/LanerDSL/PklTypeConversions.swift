import LanerMatch

// MARK: - Pkl ↔ Swift Type Conversions

extension Lanerfile.BuildConfiguration {
    var toBuildConfiguration: BuildConfiguration {
        switch self {
        case .debug: .debug
        case .release: .release
        }
    }
}

extension Lanerfile.ExportMethod {
    var toExportMethod: ExportMethod {
        switch self {
        case .appStore: .appStore
        case .adHoc: .adHoc
        case .development: .development
        case .enterprise: .enterprise
        }
    }
}

extension Lanerfile.CertificateType {
    var toCertificateType: CertificateType {
        switch self {
        case .development: .development
        case .distribution: .distribution
        case .adhoc: .adhoc
        case .appstore: .appstore
        }
    }
}

extension Lanerfile.DevicePlatform {
    var toDevicePlatform: Device.Platform {
        switch self {
        case .iOS: .iOS
        case .macOS: .macOS
        case .tvOS: .tvOS
        case .watchOS: .watchOS
        case .visionOS: .visionOS
        }
    }
}
