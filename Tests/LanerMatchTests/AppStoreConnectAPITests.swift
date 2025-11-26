import Testing
import Foundation
@testable import LanerMatch

@Suite("App Store Connect API Tests")
struct AppStoreConnectAPITests {

    @Test("JWT token generation with valid key")
    func testJWTTokenGeneration() throws {
        // Sample P-256 private key (test key, not real)
        let privateKey = """
        -----BEGIN PRIVATE KEY-----
        MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgPGJGAm4X1fvBuC1z
        SpO/4Gear0aKE8OuC1a/eHM5Mz6hRANCAATRJbvPcvLf5l3gKDmVLp8mLdHl1OtH
        R/J6fQSvZqEbJWVcYVh5jBXV3VhNMnVlYwM1zNxVCLZGD0aVhJXVZqEl
        -----END PRIVATE KEY-----
        """

        let generator = try JWTGenerator(
            keyId: "TEST_KEY_ID",
            issuerId: "TEST_ISSUER_ID",
            privateKey: privateKey
        )

        let token = try generator.generateToken()

        // Verify token structure
        let components = token.split(separator: ".")
        #expect(components.count == 3, "JWT should have 3 parts: header, payload, signature")

        // Decode and verify header
        let headerData = Data(base64URLEncoded: String(components[0]))
        #expect(headerData != nil, "Header should be valid base64")

        if let headerData = headerData {
            let header = try JSONDecoder().decode(JWTHeader.self, from: headerData)
            #expect(header.alg == "ES256")
            #expect(header.kid == "TEST_KEY_ID")
            #expect(header.typ == "JWT")
        }

        // Decode and verify payload
        let payloadData = Data(base64URLEncoded: String(components[1]))
        #expect(payloadData != nil, "Payload should be valid base64")

        if let payloadData = payloadData {
            let payload = try JSONDecoder().decode(JWTPayload.self, from: payloadData)
            #expect(payload.iss == "TEST_ISSUER_ID")
            #expect(payload.aud == "appstoreconnect-v1")

            // Verify expiration is approximately 20 minutes in the future
            let expectedExp = Int(Date().timeIntervalSince1970) + (20 * 60)
            let expDiff = abs(payload.exp - expectedExp)
            #expect(expDiff < 5, "Expiration should be ~20 minutes from now")
        }
    }

    @Test("JWT token generation with .p8 format key")
    func testJWTTokenGenerationP8Format() throws {
        // Sample key without PEM headers (like .p8 files)
        let privateKey = """
        MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgPGJGAm4X1fvBuC1z
        SpO/4Gear0aKE8OuC1a/eHM5Mz6hRANCAATRJbvPcvLf5l3gKDmVLp8mLdHl1OtH
        R/J6fQSvZqEbJWVcYVh5jBXV3VhNMnVlYwM1zNxVCLZGD0aVhJXVZqEl
        """

        let generator = try JWTGenerator(
            keyId: "KEY_123",
            issuerId: "ISSUER_456",
            privateKey: privateKey
        )

        let token = try generator.generateToken()
        #expect(!token.isEmpty, "Token should be generated successfully")
    }

    @Test("JWT token generation fails with invalid key")
    func testJWTTokenGenerationInvalidKey() {
        let invalidKey = "not-a-valid-key"

        #expect(throws: MatchError.self) {
            _ = try JWTGenerator(
                keyId: "KEY_ID",
                issuerId: "ISSUER_ID",
                privateKey: invalidKey
            )
        }
    }

    @Test("Multiple token generations produce different tokens")
    func testMultipleTokenGenerations() async throws {
        let privateKey = """
        -----BEGIN PRIVATE KEY-----
        MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgPGJGAm4X1fvBuC1z
        SpO/4Gear0aKE8OuC1a/eHM5Mz6hRANCAATRJbvPcvLf5l3gKDmVLp8mLdHl1OtH
        R/J6fQSvZqEbJWVcYVh5jBXV3VhNMnVlYwM1zNxVCLZGD0aVhJXVZqEl
        -----END PRIVATE KEY-----
        """

        let generator = try JWTGenerator(
            keyId: "KEY_ID",
            issuerId: "ISSUER_ID",
            privateKey: privateKey
        )

        let token1 = try generator.generateToken()

        // Wait a moment to ensure different timestamps
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        let token2 = try generator.generateToken()

        // Tokens should be different due to different timestamps
        #expect(token1 != token2, "Tokens generated at different times should differ")
    }
}

// MARK: - Test Helpers

private struct JWTHeader: Codable {
    let alg: String
    let kid: String
    let typ: String
}

private struct JWTPayload: Codable {
    let iss: String
    let iat: Int
    let exp: Int
    let aud: String
}

private extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        self.init(base64Encoded: base64)
    }
}
