import Testing
import Foundation
@testable import SwiftlaneMatch

@Suite("TestFlight Model Tests")
struct TestFlightModelsTests {

    // MARK: - Build Tests

    @Test("Build decodes from JSON correctly")
    func testBuildDecoding() throws {
        let json = """
        {
            "id": "build-123",
            "version": "42",
            "appVersion": "1.2.3",
            "processingState": "VALID",
            "uploadedDate": "2024-01-15T10:30:00Z",
            "minOsVersion": "16.0",
            "usesNonExemptEncryption": false
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let build = try decoder.decode(Build.self, from: json.data(using: .utf8)!)

        #expect(build.id == "build-123")
        #expect(build.version == "42")
        #expect(build.appVersion == "1.2.3")
        #expect(build.processingState == .valid)
        #expect(build.minOsVersion == "16.0")
        #expect(build.usesNonExemptEncryption == false)
    }

    @Test("Build processing state decodes all valid states")
    func testBuildProcessingStateDecoding() throws {
        let states = ["PROCESSING", "FAILED", "INVALID", "VALID"]
        let expected: [Build.ProcessingState] = [.processing, .failed, .invalid, .valid]

        for (json, expectedState) in zip(states, expected) {
            let jsonString = "\"\(json)\""
            let state = try JSONDecoder().decode(Build.ProcessingState.self, from: jsonString.data(using: .utf8)!)
            #expect(state == expectedState, "Expected \(expectedState) for \(json)")
        }
    }

    @Test("Build processing state decodes unknown states")
    func testBuildProcessingStateUnknown() throws {
        let json = "\"FUTURE_STATE\""
        let state = try JSONDecoder().decode(Build.ProcessingState.self, from: json.data(using: .utf8)!)
        #expect(state == .unknown)
    }

    @Test("Build equality check works")
    func testBuildEquality() {
        let build1 = Build(id: "123", version: "42", processingState: .valid)
        let build2 = Build(id: "123", version: "42", processingState: .valid)
        let build3 = Build(id: "456", version: "42", processingState: .valid)

        #expect(build1 == build2)
        #expect(build1 != build3)
    }

    // MARK: - BuildUpload Tests

    @Test("BuildUpload decodes from JSON correctly")
    func testBuildUploadDecoding() throws {
        let json = """
        {
            "id": "upload-123",
            "uploadState": "AWAITING_FILES"
        }
        """

        let upload = try JSONDecoder().decode(BuildUpload.self, from: json.data(using: .utf8)!)

        #expect(upload.id == "upload-123")
        #expect(upload.uploadState == .awaitingFiles)
    }

    @Test("BuildUpload upload state decodes all valid states")
    func testBuildUploadStateDecoding() throws {
        let states = ["AWAITING_FILES", "UPLOADING", "COMPLETE", "FAILED"]
        let expected: [BuildUpload.UploadState] = [.awaitingFiles, .uploading, .complete, .failed]

        for (json, expectedState) in zip(states, expected) {
            let jsonString = "\"\(json)\""
            let state = try JSONDecoder().decode(BuildUpload.UploadState.self, from: jsonString.data(using: .utf8)!)
            #expect(state == expectedState)
        }
    }

    // MARK: - BuildUploadFile Tests

    @Test("BuildUploadFile initializes correctly")
    func testBuildUploadFileInit() {
        let file = BuildUploadFile(
            id: "file-123",
            uploadUrl: "https://s3.amazonaws.com/bucket/file",
            fileId: "file-456"
        )

        #expect(file.id == "file-123")
        #expect(file.uploadUrl == "https://s3.amazonaws.com/bucket/file")
        #expect(file.fileId == "file-456")
    }

    // MARK: - ChunkInfo Tests

    @Test("ChunkInfo initializes correctly")
    func testChunkInfoInit() {
        let chunk = ChunkInfo(
            index: 0,
            offset: 0,
            size: 50 * 1024 * 1024,
            totalSize: 100 * 1024 * 1024,
            checksum: "abc123"
        )

        #expect(chunk.index == 0)
        #expect(chunk.offset == 0)
        #expect(chunk.size == 50 * 1024 * 1024)
        #expect(chunk.totalSize == 100 * 1024 * 1024)
        #expect(chunk.checksum == "abc123")
    }

    // MARK: - BetaGroup Tests

    @Test("BetaGroup decodes from JSON correctly")
    func testBetaGroupDecoding() throws {
        let json = """
        {
            "id": "group-123",
            "name": "Internal Testers",
            "isInternalGroup": true,
            "publicLinkEnabled": false,
            "publicLink": null
        }
        """

        let group = try JSONDecoder().decode(BetaGroup.self, from: json.data(using: .utf8)!)

        #expect(group.id == "group-123")
        #expect(group.name == "Internal Testers")
        #expect(group.isInternalGroup == true)
        #expect(group.publicLinkEnabled == false)
        #expect(group.publicLink == nil)
    }

    @Test("BetaGroup with public link decodes correctly")
    func testBetaGroupWithPublicLink() throws {
        let json = """
        {
            "id": "group-456",
            "name": "External Testers",
            "isInternalGroup": false,
            "publicLinkEnabled": true,
            "publicLink": "https://testflight.apple.com/join/abc123"
        }
        """

        let group = try JSONDecoder().decode(BetaGroup.self, from: json.data(using: .utf8)!)

        #expect(group.isInternalGroup == false)
        #expect(group.publicLinkEnabled == true)
        #expect(group.publicLink == "https://testflight.apple.com/join/abc123")
    }

    // MARK: - UploadProgress Tests

    @Test("UploadProgress percentage calculation")
    func testUploadProgressPercentage() {
        let progress = UploadProgress(
            bytesUploaded: 50 * 1024 * 1024,
            totalBytes: 100 * 1024 * 1024,
            currentChunk: 1,
            totalChunks: 2
        )

        #expect(progress.percentage == 50.0)
    }

    @Test("UploadProgress percentage handles zero total bytes")
    func testUploadProgressZeroBytes() {
        let progress = UploadProgress(
            bytesUploaded: 0,
            totalBytes: 0,
            currentChunk: 0,
            totalChunks: 0
        )

        #expect(progress.percentage == 0.0)
    }

    @Test("UploadProgress 100% complete")
    func testUploadProgressComplete() {
        let progress = UploadProgress(
            bytesUploaded: 100_000_000,
            totalBytes: 100_000_000,
            currentChunk: 2,
            totalChunks: 2
        )

        #expect(progress.percentage == 100.0)
    }

    // MARK: - TestFlightError Tests

    @Test("TestFlightError descriptions are informative")
    func testTestFlightErrorDescriptions() {
        let errors: [TestFlightError] = [
            .ipaNotFound("/path/to/app.ipa"),
            .invalidIPA("Not a valid ZIP archive"),
            .uploadCreationFailed("Server error"),
            .chunkUploadFailed(chunkIndex: 2, reason: "Network timeout"),
            .uploadCompletionFailed("Invalid checksum"),
            .processingTimeout,
            .processingFailed("Binary invalid"),
            .groupNotFound("External Beta"),
            .distributionFailed("Group full"),
            .rateLimited(retryAfter: 60),
            .apiError("Unauthorized"),
            .missingAppId,
            .missingCredentials("APP_STORE_CONNECT_API_KEY_ID"),
            .platformNotSupported,
        ]

        for error in errors {
            #expect(error.errorDescription != nil, "Error \(error) should have a description")
            #expect(!error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }

    @Test("TestFlightError equality")
    func testTestFlightErrorEquality() {
        let error1 = TestFlightError.ipaNotFound("/path/to/app.ipa")
        let error2 = TestFlightError.ipaNotFound("/path/to/app.ipa")
        let error3 = TestFlightError.ipaNotFound("/different/path.ipa")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}
