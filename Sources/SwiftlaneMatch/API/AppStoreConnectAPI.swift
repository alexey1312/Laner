import Foundation
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import Logging
import SwiftlaneKit

/// Actor-based client for App Store Connect API
public actor AppStoreConnectAPI {
    private let keyId: String
    private let issuerId: String
    private let privateKeyPath: String
    private let jwtGenerator: JWTGenerator
    let httpClient: HTTPClient
    let logger: Logger
    let baseURL = "https://api.appstoreconnect.apple.com/v1"

    private var cachedToken: String?
    private var tokenExpiration: Date?

    /// Initializes the App Store Connect API client
    /// - Parameters:
    ///   - keyId: API Key ID from App Store Connect
    ///   - issuerId: Issuer ID (Team ID)
    ///   - privateKeyPath: Path to the .p8 private key file
    /// - Throws: If the private key cannot be loaded
    public init(keyId: String, issuerId: String, privateKeyPath: String) throws {
        // Validate and create JWT generator FIRST (before creating HTTP client)
        // This ensures we don't create HTTP client if validation fails
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: privateKeyPath, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw MatchError.fileNotFound(privateKeyPath)
        }

        let privateKeyContent = try String(contentsOfFile: privateKeyPath, encoding: .utf8)
        let generator = try JWTGenerator(keyId: keyId, issuerId: issuerId, privateKey: privateKeyContent)

        // Only after validation succeeds, initialize all stored properties
        self.keyId = keyId
        self.issuerId = issuerId
        self.privateKeyPath = privateKeyPath
        self.jwtGenerator = generator
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        self.logger = Logger(label: "com.swiftlane.match.api")
    }

    /// Shuts down the HTTP client. Call this when done using the API client.
    public func shutdown() async throws {
        try await httpClient.shutdown()
    }

    // MARK: - Authentication

    /// Gets a valid JWT token, refreshing if necessary
    func getToken() throws -> String {
        let now = Date()

        // Check if we have a valid cached token
        if let token = cachedToken,
           let expiration = tokenExpiration,
           now < expiration.addingTimeInterval(-60) { // Refresh 1 minute before expiry
            return token
        }

        // Generate new token
        let token = try jwtGenerator.generateToken()
        cachedToken = token
        tokenExpiration = now.addingTimeInterval(20 * 60) // 20 minutes

        logger.debug("Generated new JWT token")
        return token
    }

    // MARK: - HTTP Requests

    func executeRequest<T: Decodable>(
        method: HTTPMethod,
        path: String,
        body: Data? = nil
    ) async throws -> T {
        let token = try getToken()
        let url = "\(baseURL)\(path)"

        var request = HTTPClientRequest(url: url)
        request.method = method
        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.headers.add(name: "Content-Type", value: "application/json")

        if let body = body {
            request.body = .bytes(ByteBuffer(bytes: body))
        }

        logger.debug("Request: \(method.rawValue) \(path)")

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok || response.status == .created else {
            let bodyBytes = try await response.body.collect(upTo: 1024 * 1024) // 1MB
            let bodyString = String(buffer: bodyBytes)
            logger.error("API error: \(response.status.code) - \(bodyString)")
            throw MatchError.apiRequestFailed("HTTP \(response.status.code): \(bodyString)")
        }

        let bodyBytes = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10MB
        let data = Data(bodyBytes.readableBytesView)

        do {
            return try JSONDecoder.appStoreConnect.decode(T.self, from: data)
        } catch {
            logger.error("Failed to decode response: \(error)")
            throw MatchError.apiRequestFailed("Failed to decode response: \(error.localizedDescription)")
        }
    }

    private func executeDeleteRequest(path: String) async throws {
        let token = try getToken()
        let url = "\(baseURL)\(path)"

        var request = HTTPClientRequest(url: url)
        request.method = .DELETE
        request.headers.add(name: "Authorization", value: "Bearer \(token)")

        logger.debug("Request: DELETE \(path)")

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .noContent || response.status == .ok else {
            let bodyBytes = try await response.body.collect(upTo: 1024 * 1024) // 1MB
            let bodyString = String(buffer: bodyBytes)
            logger.error("API error: \(response.status.code) - \(bodyString)")
            throw MatchError.apiRequestFailed("HTTP \(response.status.code): \(bodyString)")
        }
    }

    // MARK: - Certificates

    /// Lists all certificates of a specific type
    /// - Parameter type: Optional certificate type filter
    /// - Returns: Array of certificates
    public func listCertificates(type: CertificateType? = nil) async throws -> [Certificate] {
        var path = "/certificates?limit=200"
        if let type = type {
            path += "&filter[certificateType]=\(type.appleType)"
        }

        let response: CertificatesResponse = try await executeRequest(method: .GET, path: path)
        return response.data.map { apiCert in
            Certificate(
                id: apiCert.id,
                serialNumber: apiCert.attributes.serialNumber,
                name: apiCert.attributes.name,
                type: CertificateType.from(appleType: apiCert.attributes.certificateType),
                teamId: "", // Not provided in list response
                expirationDate: apiCert.attributes.expirationDate,
                content: apiCert.attributes.certificateContent.flatMap { Data(base64Encoded: $0) }
            )
        }
    }

    /// Creates a new certificate
    /// - Parameters:
    ///   - type: Certificate type to create
    ///   - csrContent: Certificate Signing Request content (PEM format)
    /// - Returns: Created certificate
    public func createCertificate(type: CertificateType, csrContent: String) async throws -> Certificate {
        let requestBody = CreateCertificateRequest(
            data: CreateCertificateRequest.Data(
                type: "certificates",
                attributes: CreateCertificateRequest.Attributes(
                    certificateType: type.appleType,
                    csrContent: csrContent
                )
            )
        )

        let bodyData = try JSONEncoder.appStoreConnect.encode(requestBody)
        let response: CreateCertificateResponse = try await executeRequest(
            method: .POST,
            path: "/certificates",
            body: bodyData
        )

        return Certificate(
            id: response.data.id,
            serialNumber: response.data.attributes.serialNumber,
            name: response.data.attributes.name,
            type: type,
            teamId: "",
            expirationDate: response.data.attributes.expirationDate,
            content: response.data.attributes.certificateContent.flatMap { Data(base64Encoded: $0) }
        )
    }

    /// Revokes a certificate
    /// - Parameter id: Certificate ID to revoke
    public func revokeCertificate(id: String) async throws {
        try await executeDeleteRequest(path: "/certificates/\(id)")
    }

    // MARK: - Provisioning Profiles

    /// Lists provisioning profiles
    /// - Parameters:
    ///   - type: Optional profile type filter
    ///   - bundleId: Optional bundle ID filter
    /// - Returns: Array of provisioning profiles
    public func listProfiles(type: CertificateType? = nil, bundleId: String? = nil) async throws -> [ProvisioningProfile] {
        var path = "/profiles?limit=200"
        if let type = type {
            path += "&filter[profileType]=\(type.profileType)"
        }
        if let bundleId = bundleId {
            path += "&filter[name]=\(bundleId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bundleId)"
        }

        let response: ProfilesResponse = try await executeRequest(method: .GET, path: path)
        return response.data.map { apiProfile in
            ProvisioningProfile(
                id: apiProfile.id,
                uuid: apiProfile.attributes.uuid,
                name: apiProfile.attributes.name,
                bundleId: apiProfile.attributes.bundleId ?? "",
                type: CertificateType.from(profileType: apiProfile.attributes.profileType),
                teamId: "",
                teamName: "",
                expirationDate: apiProfile.attributes.expirationDate,
                certificateIds: [],
                deviceIds: [],
                content: apiProfile.attributes.profileContent.flatMap { Data(base64Encoded: $0) }
            )
        }
    }

    /// Creates a new provisioning profile
    /// - Parameters:
    ///   - name: Profile name
    ///   - type: Certificate type
    ///   - bundleIdResource: Bundle ID resource identifier
    ///   - certificateIds: Certificate IDs to include
    ///   - deviceIds: Device IDs to include (for development/adhoc)
    /// - Returns: Created provisioning profile
    public func createProfile(
        name: String,
        type: CertificateType,
        bundleIdResource: String,
        certificateIds: [String],
        deviceIds: [String]
    ) async throws -> ProvisioningProfile {
        let requestBody = CreateProfileRequest(
            data: CreateProfileRequest.Data(
                type: "profiles",
                attributes: CreateProfileRequest.Attributes(
                    name: name,
                    profileType: type.profileType
                ),
                relationships: CreateProfileRequest.Relationships(
                    bundleId: CreateProfileRequest.RelatedResource(
                        data: CreateProfileRequest.ResourceIdentifier(
                            id: bundleIdResource,
                            type: "bundleIds"
                        )
                    ),
                    certificates: CreateProfileRequest.RelatedResources(
                        data: certificateIds.map { id in
                            CreateProfileRequest.ResourceIdentifier(id: id, type: "certificates")
                        }
                    ),
                    devices: deviceIds.isEmpty ? nil : CreateProfileRequest.RelatedResources(
                        data: deviceIds.map { id in
                            CreateProfileRequest.ResourceIdentifier(id: id, type: "devices")
                        }
                    )
                )
            )
        )

        let bodyData = try JSONEncoder.appStoreConnect.encode(requestBody)
        let response: CreateProfileResponse = try await executeRequest(
            method: .POST,
            path: "/profiles",
            body: bodyData
        )

        return ProvisioningProfile(
            id: response.data.id,
            uuid: response.data.attributes.uuid,
            name: response.data.attributes.name,
            bundleId: response.data.attributes.bundleId ?? "",
            type: type,
            teamId: "",
            teamName: "",
            expirationDate: response.data.attributes.expirationDate,
            certificateIds: certificateIds,
            deviceIds: deviceIds,
            content: response.data.attributes.profileContent.flatMap { Data(base64Encoded: $0) }
        )
    }

    /// Deletes a provisioning profile
    /// - Parameter id: Profile ID to delete
    public func deleteProfile(id: String) async throws {
        try await executeDeleteRequest(path: "/profiles/\(id)")
    }

    // MARK: - Devices

    /// Lists registered devices
    /// - Parameter platform: Optional platform filter
    /// - Returns: Array of devices
    public func listDevices(platform: Device.Platform? = nil) async throws -> [Device] {
        var path = "/devices?limit=200"
        if let platform = platform {
            path += "&filter[platform]=\(platform.rawValue)"
        }

        let response: DevicesResponse = try await executeRequest(method: .GET, path: path)
        return response.data.map { apiDevice in
            Device(
                id: apiDevice.id,
                udid: apiDevice.attributes.udid,
                name: apiDevice.attributes.name,
                platform: Device.Platform(rawValue: apiDevice.attributes.platform) ?? .iOS,
                deviceClass: Device.DeviceClass(rawValue: apiDevice.attributes.deviceClass) ?? .unknown,
                status: Device.Status(rawValue: apiDevice.attributes.status) ?? .enabled,
                addedDate: apiDevice.attributes.addedDate
            )
        }
    }

    /// Registers a new device
    /// - Parameters:
    ///   - name: Device name
    ///   - udid: Device UDID
    ///   - platform: Device platform
    /// - Returns: Registered device
    public func registerDevice(name: String, udid: String, platform: Device.Platform) async throws -> Device {
        let requestBody = RegisterDeviceRequest(
            data: RegisterDeviceRequest.Data(
                type: "devices",
                attributes: RegisterDeviceRequest.Attributes(
                    name: name,
                    udid: udid,
                    platform: platform.rawValue
                )
            )
        )

        let bodyData = try JSONEncoder.appStoreConnect.encode(requestBody)
        let response: RegisterDeviceResponse = try await executeRequest(
            method: .POST,
            path: "/devices",
            body: bodyData
        )

        return Device(
            id: response.data.id,
            udid: response.data.attributes.udid,
            name: response.data.attributes.name,
            platform: Device.Platform(rawValue: response.data.attributes.platform) ?? .iOS,
            deviceClass: Device.DeviceClass(rawValue: response.data.attributes.deviceClass) ?? .unknown,
            status: Device.Status(rawValue: response.data.attributes.status) ?? .enabled,
            addedDate: response.data.attributes.addedDate
        )
    }
}

// MARK: - API Models

// Certificates
private struct CertificatesResponse: Codable {
    let data: [CertificateData]
}

private struct CertificateData: Codable {
    let id: String
    let attributes: CertificateAttributes
}

private struct CertificateAttributes: Codable {
    let serialNumber: String
    let name: String
    let certificateType: String
    let expirationDate: Date
    let certificateContent: String?
}

private struct CreateCertificateRequest: Codable {
    let data: Data

    struct Data: Codable {
        let type: String
        let attributes: Attributes
    }

    struct Attributes: Codable {
        let certificateType: String
        let csrContent: String
    }
}

private struct CreateCertificateResponse: Codable {
    let data: CertificateData
}

// Profiles
private struct ProfilesResponse: Codable {
    let data: [ProfileData]
}

private struct ProfileData: Codable {
    let id: String
    let attributes: ProfileAttributes
}

private struct ProfileAttributes: Codable {
    let uuid: String
    let name: String
    let profileType: String
    let bundleId: String?
    let expirationDate: Date
    let profileContent: String?
}

private struct CreateProfileRequest: Codable {
    let data: Data

    struct Data: Codable {
        let type: String
        let attributes: Attributes
        let relationships: Relationships
    }

    struct Attributes: Codable {
        let name: String
        let profileType: String
    }

    struct Relationships: Codable {
        let bundleId: RelatedResource
        let certificates: RelatedResources
        let devices: RelatedResources?
    }

    struct RelatedResource: Codable {
        let data: ResourceIdentifier
    }

    struct RelatedResources: Codable {
        let data: [ResourceIdentifier]
    }

    struct ResourceIdentifier: Codable {
        let id: String
        let type: String
    }
}

private struct CreateProfileResponse: Codable {
    let data: ProfileData
}

// Devices
private struct DevicesResponse: Codable {
    let data: [DeviceData]
}

private struct DeviceData: Codable {
    let id: String
    let attributes: DeviceAttributes
}

private struct DeviceAttributes: Codable {
    let udid: String
    let name: String
    let platform: String
    let deviceClass: String
    let status: String
    let addedDate: Date?
}

private struct RegisterDeviceRequest: Codable {
    let data: Data

    struct Data: Codable {
        let type: String
        let attributes: Attributes
    }

    struct Attributes: Codable {
        let name: String
        let udid: String
        let platform: String
    }
}

private struct RegisterDeviceResponse: Codable {
    let data: DeviceData
}

// MARK: - Helpers

private extension CertificateType {
    static func from(appleType: String) -> CertificateType {
        switch appleType {
        case "IOS_DEVELOPMENT", "MAC_APP_DEVELOPMENT", "DEVELOPMENT":
            return .development
        case "IOS_DISTRIBUTION", "MAC_APP_DISTRIBUTION", "DISTRIBUTION":
            return .distribution
        default:
            return .distribution
        }
    }

    static func from(profileType: String) -> CertificateType {
        switch profileType {
        case "IOS_APP_DEVELOPMENT", "MAC_APP_DEVELOPMENT":
            return .development
        case "IOS_APP_STORE", "MAC_APP_STORE", "TVOS_APP_STORE":
            return .appstore
        case "IOS_APP_ADHOC", "TVOS_APP_ADHOC":
            return .adhoc
        default:
            return .appstore
        }
    }
}

private extension JSONDecoder {
    static var appStoreConnect: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var appStoreConnect: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
