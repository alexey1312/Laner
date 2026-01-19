import AsyncHTTPClient
import Foundation
import Logging
import NIOCore
import NIOHTTP1

// MARK: - Build Upload API v4.1+

public extension AppStoreConnectAPI {
    /// Creates a new build upload session.
    /// - Parameter appId: The App Store Connect app ID.
    /// - Returns: The created build upload session.
    func createBuildUpload(appId: String) async throws -> BuildUpload {
        let requestBody = CreateBuildUploadRequest(
            data: CreateBuildUploadRequest.Data(
                type: "buildUploads",
                relationships: CreateBuildUploadRequest.Relationships(
                    app: CreateBuildUploadRequest.RelatedApp(
                        data: CreateBuildUploadRequest.AppData(
                            id: appId,
                            type: "apps"
                        )
                    )
                )
            )
        )

        let bodyData = try JSONEncoder.appStoreConnect.encode(requestBody)
        let response: BuildUploadResponse = try await executeRequest(
            method: .POST,
            path: "/buildUploads",
            body: bodyData
        )

        return BuildUpload(
            id: response.data.id,
            uploadState: BuildUpload.UploadState(rawValue: response.data.attributes.uploadState) ?? .unknown
        )
    }

    /// Reserves a slot for uploading a file chunk.
    /// - Parameters:
    ///   - buildUploadId: The build upload session ID.
    ///   - chunk: Information about the chunk to upload.
    /// - Returns: The file reservation with upload URL.
    func reserveBuildUploadFile(
        buildUploadId: String,
        chunk: ChunkInfo
    ) async throws -> BuildUploadFile {
        let requestBody = ReserveBuildUploadFileRequest(
            data: ReserveBuildUploadFileRequest.Data(
                type: "buildUploadFiles",
                attributes: ReserveBuildUploadFileRequest.Attributes(
                    fileName: "app.ipa",
                    fileSize: chunk.totalSize,
                    chunkIndex: chunk.index,
                    chunkSize: chunk.size,
                    checksum: chunk.checksum
                ),
                relationships: ReserveBuildUploadFileRequest.Relationships(
                    buildUpload: ReserveBuildUploadFileRequest.RelatedBuildUpload(
                        data: ReserveBuildUploadFileRequest.BuildUploadData(
                            id: buildUploadId,
                            type: "buildUploads"
                        )
                    )
                )
            )
        )

        let bodyData = try JSONEncoder.appStoreConnect.encode(requestBody)
        let response: BuildUploadFileResponse = try await executeRequest(
            method: .POST,
            path: "/buildUploadFiles",
            body: bodyData
        )

        guard let uploadUrl = response.data.attributes.uploadUrl else {
            throw TestFlightError.uploadCreationFailed("No upload URL returned")
        }

        return BuildUploadFile(
            id: response.data.id,
            uploadUrl: uploadUrl,
            fileId: response.data.id
        )
    }

    /// Commits an uploaded file chunk.
    /// - Parameter fileId: The file ID to commit.
    func commitBuildUploadFile(fileId: String) async throws {
        let requestBody = CommitBuildUploadFileRequest(
            data: CommitBuildUploadFileRequest.Data(
                id: fileId,
                type: "buildUploadFiles",
                attributes: CommitBuildUploadFileRequest.Attributes(
                    uploaded: true
                )
            )
        )

        let bodyData = try JSONEncoder.appStoreConnect.encode(requestBody)
        let _: BuildUploadFileResponse = try await executeRequest(
            method: .PATCH,
            path: "/buildUploadFiles/\(fileId)",
            body: bodyData
        )
    }

    /// Completes the build upload session.
    /// - Parameter buildUploadId: The build upload session ID.
    func completeBuildUpload(buildUploadId: String) async throws {
        let requestBody = CompleteBuildUploadRequest(
            data: CompleteBuildUploadRequest.Data(
                id: buildUploadId,
                type: "buildUploads",
                attributes: CompleteBuildUploadRequest.Attributes(
                    uploaded: true
                )
            )
        )

        let bodyData = try JSONEncoder.appStoreConnect.encode(requestBody)
        let _: BuildUploadResponse = try await executeRequest(
            method: .PATCH,
            path: "/buildUploads/\(buildUploadId)",
            body: bodyData
        )
    }
}

// MARK: - Builds API

public extension AppStoreConnectAPI {
    /// Lists builds for an app.
    /// - Parameters:
    ///   - appId: The App Store Connect app ID.
    ///   - limit: Maximum number of builds to return (default: 10).
    /// - Returns: Array of builds.
    func listBuilds(appId: String, limit: Int = 10) async throws -> [Build] {
        let path = "/builds?filter[app]=\(appId)&limit=\(limit)&sort=-uploadedDate"

        let response: BuildsResponse = try await executeRequest(method: .GET, path: path)
        return response.data.map { buildData in
            Build(
                id: buildData.id,
                version: buildData.attributes.version,
                appVersion: buildData.attributes.appVersion,
                processingState: Build.ProcessingState(rawValue: buildData.attributes.processingState) ?? .unknown,
                uploadedDate: buildData.attributes.uploadedDate,
                minOsVersion: buildData.attributes.minOsVersion,
                usesNonExemptEncryption: buildData.attributes.usesNonExemptEncryption
            )
        }
    }

    /// Gets a specific build by ID.
    /// - Parameter id: The build ID.
    /// - Returns: The build.
    func getBuild(id: String) async throws -> Build {
        let response: BuildResponse = try await executeRequest(method: .GET, path: "/builds/\(id)")
        return Build(
            id: response.data.id,
            version: response.data.attributes.version,
            appVersion: response.data.attributes.appVersion,
            processingState: Build.ProcessingState(rawValue: response.data.attributes.processingState) ?? .unknown,
            uploadedDate: response.data.attributes.uploadedDate,
            minOsVersion: response.data.attributes.minOsVersion,
            usesNonExemptEncryption: response.data.attributes.usesNonExemptEncryption
        )
    }
}

// MARK: - Beta Groups API

extension AppStoreConnectAPI {
    /// Lists beta groups for an app.
    /// - Parameter appId: The App Store Connect app ID.
    /// - Returns: Array of beta groups.
    public func listBetaGroups(appId: String) async throws -> [BetaGroup] {
        let path = "/betaGroups?filter[app]=\(appId)&limit=100"

        let response: BetaGroupsResponse = try await executeRequest(method: .GET, path: path)
        return response.data.map { groupData in
            BetaGroup(
                id: groupData.id,
                name: groupData.attributes.name,
                isInternalGroup: groupData.attributes.isInternalGroup,
                publicLinkEnabled: groupData.attributes.publicLinkEnabled,
                publicLink: groupData.attributes.publicLink
            )
        }
    }

    /// Adds a build to a beta group.
    /// - Parameters:
    ///   - buildId: The build ID.
    ///   - groupId: The beta group ID.
    public func addBuildToBetaGroup(buildId: String, groupId: String) async throws {
        let requestBody = AddBuildToBetaGroupRequest(
            data: [AddBuildToBetaGroupRequest.BuildData(id: buildId, type: "builds")]
        )

        let bodyData = try JSONEncoder.appStoreConnect.encode(requestBody)
        try await executePostRequest(
            path: "/betaGroups/\(groupId)/relationships/builds",
            body: bodyData
        )
    }

    /// Sets the beta test information (what's new) for a build.
    /// - Parameters:
    ///   - buildId: The build ID.
    ///   - locale: The locale for the text (default: en-US).
    ///   - whatsNew: The what's new text.
    public func setBetaTestInfo(
        buildId: String,
        locale: String = "en-US",
        whatsNew: String
    ) async throws {
        // First, get or create the beta build localization
        let existingLocalizations = try await listBetaBuildLocalizations(buildId: buildId)

        if let existing = existingLocalizations.first(where: { $0.locale == locale }) {
            // Update existing localization
            try await updateBetaBuildLocalization(id: existing.id, whatsNew: whatsNew)
        } else {
            // Create new localization
            try await createBetaBuildLocalization(buildId: buildId, locale: locale, whatsNew: whatsNew)
        }
    }

    private func listBetaBuildLocalizations(buildId: String) async throws -> [BetaBuildLocalization] {
        let path = "/builds/\(buildId)/betaBuildLocalizations"
        let response: BetaBuildLocalizationsResponse = try await executeRequest(method: .GET, path: path)
        return response.data.map { data in
            BetaBuildLocalization(id: data.id, locale: data.attributes.locale, whatsNew: data.attributes.whatsNew)
        }
    }

    private func createBetaBuildLocalization(buildId: String, locale: String, whatsNew: String) async throws {
        let requestBody = CreateBetaBuildLocalizationRequest(
            data: CreateBetaBuildLocalizationRequest.Data(
                type: "betaBuildLocalizations",
                attributes: CreateBetaBuildLocalizationRequest.Attributes(
                    locale: locale,
                    whatsNew: whatsNew
                ),
                relationships: CreateBetaBuildLocalizationRequest.Relationships(
                    build: CreateBetaBuildLocalizationRequest.RelatedBuild(
                        data: CreateBetaBuildLocalizationRequest.BuildData(
                            id: buildId,
                            type: "builds"
                        )
                    )
                )
            )
        )

        let bodyData = try JSONEncoder.appStoreConnect.encode(requestBody)
        let _: BetaBuildLocalizationResponse = try await executeRequest(
            method: .POST,
            path: "/betaBuildLocalizations",
            body: bodyData
        )
    }

    private func updateBetaBuildLocalization(id: String, whatsNew: String) async throws {
        let requestBody = UpdateBetaBuildLocalizationRequest(
            data: UpdateBetaBuildLocalizationRequest.Data(
                id: id,
                type: "betaBuildLocalizations",
                attributes: UpdateBetaBuildLocalizationRequest.Attributes(
                    whatsNew: whatsNew
                )
            )
        )

        let bodyData = try JSONEncoder.appStoreConnect.encode(requestBody)
        let _: BetaBuildLocalizationResponse = try await executeRequest(
            method: .PATCH,
            path: "/betaBuildLocalizations/\(id)",
            body: bodyData
        )
    }

    // MARK: - Internal Helper

    private func executePostRequest(path: String, body: Data) async throws {
        let token = try getToken()
        let url = "\(baseURL)\(path)"

        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(ByteBuffer(bytes: body))

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok || response.status == .created || response.status == .noContent else {
            let bodyBytes = try await response.body.collect(upTo: 1024 * 1024)
            let bodyString = String(buffer: bodyBytes)
            throw TestFlightError.apiError("HTTP \(response.status.code): \(bodyString)")
        }
    }
}

// MARK: - API Request/Response Models

// Build Upload
private struct CreateBuildUploadRequest: Codable {
    let data: Data

    struct Data: Codable {
        let type: String
        let relationships: Relationships
    }

    struct Relationships: Codable {
        let app: RelatedApp
    }

    struct RelatedApp: Codable {
        let data: AppData
    }

    struct AppData: Codable {
        let id: String
        let type: String
    }
}

private struct BuildUploadResponse: Codable {
    let data: BuildUploadData

    struct BuildUploadData: Codable {
        let id: String
        let attributes: Attributes
    }

    struct Attributes: Codable {
        let uploadState: String
    }
}

private struct ReserveBuildUploadFileRequest: Codable {
    let data: Data

    struct Data: Codable {
        let type: String
        let attributes: Attributes
        let relationships: Relationships
    }

    struct Attributes: Codable {
        let fileName: String
        let fileSize: Int64
        let chunkIndex: Int
        let chunkSize: Int64
        let checksum: String
    }

    struct Relationships: Codable {
        let buildUpload: RelatedBuildUpload
    }

    struct RelatedBuildUpload: Codable {
        let data: BuildUploadData
    }

    struct BuildUploadData: Codable {
        let id: String
        let type: String
    }
}

private struct BuildUploadFileResponse: Codable {
    let data: FileData

    struct FileData: Codable {
        let id: String
        let attributes: Attributes
    }

    struct Attributes: Codable {
        let uploadUrl: String?
        let uploaded: Bool?
    }
}

private struct CommitBuildUploadFileRequest: Codable {
    let data: Data

    struct Data: Codable {
        let id: String
        let type: String
        let attributes: Attributes
    }

    struct Attributes: Codable {
        let uploaded: Bool
    }
}

private struct CompleteBuildUploadRequest: Codable {
    let data: Data

    struct Data: Codable {
        let id: String
        let type: String
        let attributes: Attributes
    }

    struct Attributes: Codable {
        let uploaded: Bool
    }
}

// Builds
private struct BuildsResponse: Codable {
    let data: [BuildData]
}

private struct BuildResponse: Codable {
    let data: BuildData
}

private struct BuildData: Codable {
    let id: String
    let attributes: BuildAttributes
}

private struct BuildAttributes: Codable {
    let version: String
    let appVersion: String?
    let processingState: String
    let uploadedDate: Date?
    let minOsVersion: String?
    let usesNonExemptEncryption: Bool?
}

// Beta Groups
private struct BetaGroupsResponse: Codable {
    let data: [BetaGroupData]
}

private struct BetaGroupData: Codable {
    let id: String
    let attributes: BetaGroupAttributes
}

private struct BetaGroupAttributes: Codable {
    let name: String
    let isInternalGroup: Bool
    let publicLinkEnabled: Bool?
    let publicLink: String?
}

private struct AddBuildToBetaGroupRequest: Codable {
    let data: [BuildData]

    struct BuildData: Codable {
        let id: String
        let type: String
    }
}

// Beta Build Localizations
private struct BetaBuildLocalization: Sendable {
    let id: String
    let locale: String
    let whatsNew: String?
}

private struct BetaBuildLocalizationsResponse: Codable {
    let data: [BetaBuildLocalizationData]
}

private struct BetaBuildLocalizationResponse: Codable {
    let data: BetaBuildLocalizationData
}

private struct BetaBuildLocalizationData: Codable {
    let id: String
    let attributes: BetaBuildLocalizationAttributes
}

private struct BetaBuildLocalizationAttributes: Codable {
    let locale: String
    let whatsNew: String?
}

private struct CreateBetaBuildLocalizationRequest: Codable {
    let data: Data

    struct Data: Codable {
        let type: String
        let attributes: Attributes
        let relationships: Relationships
    }

    struct Attributes: Codable {
        let locale: String
        let whatsNew: String
    }

    struct Relationships: Codable {
        let build: RelatedBuild
    }

    struct RelatedBuild: Codable {
        let data: BuildData
    }

    struct BuildData: Codable {
        let id: String
        let type: String
    }
}

private struct UpdateBetaBuildLocalizationRequest: Codable {
    let data: Data

    struct Data: Codable {
        let id: String
        let type: String
        let attributes: Attributes
    }

    struct Attributes: Codable {
        let whatsNew: String
    }
}

// MARK: - JSON Coding Extensions

private extension JSONEncoder {
    static var appStoreConnect: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
