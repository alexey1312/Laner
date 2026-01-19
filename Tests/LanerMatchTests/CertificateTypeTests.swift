@testable import LanerMatch
import Testing

@Suite("CertificateType Tests")
struct CertificateTypeTests {
    @Test("Storage paths are correct")
    func storagePaths() {
        #expect(CertificateType.development.storagePath == "certs/development")
        #expect(CertificateType.distribution.storagePath == "certs/distribution")
        #expect(CertificateType.adhoc.storagePath == "certs/distribution")
        #expect(CertificateType.appstore.storagePath == "certs/distribution")
    }

    @Test("Profile paths are correct")
    func profilePaths() {
        #expect(CertificateType.development.profilePath == "profiles/development")
        #expect(CertificateType.distribution.profilePath == "profiles/distribution")
        #expect(CertificateType.adhoc.profilePath == "profiles/adhoc")
        #expect(CertificateType.appstore.profilePath == "profiles/appstore")
    }

    @Test("Apple type identifiers are correct")
    func appleTypes() {
        #expect(CertificateType.development.appleType == "IOS_DEVELOPMENT")
        #expect(CertificateType.distribution.appleType == "IOS_DISTRIBUTION")
        #expect(CertificateType.adhoc.appleType == "IOS_DISTRIBUTION")
        #expect(CertificateType.appstore.appleType == "IOS_DISTRIBUTION")
    }
}
