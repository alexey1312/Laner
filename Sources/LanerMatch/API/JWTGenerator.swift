@preconcurrency import Crypto
import Foundation

/// Generates JWT tokens for App Store Connect API authentication using ES256 (ECDSA P-256)
public struct JWTGenerator: Sendable {
    private let keyId: String
    private let issuerId: String
    private let privateKey: P256.Signing.PrivateKey

    /// Initializes the JWT generator with App Store Connect credentials
    /// - Parameters:
    ///   - keyId: The Key ID from App Store Connect
    ///   - issuerId: The Issuer ID (Team ID)
    ///   - privateKey: The private key content (PEM or .p8 format)
    /// - Throws: If the private key cannot be parsed
    public init(keyId: String, issuerId: String, privateKey: String) throws {
        self.keyId = keyId
        self.issuerId = issuerId

        // Parse the private key
        // Remove PEM headers/footers if present and normalize whitespace
        let cleanedKey = privateKey
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----BEGIN EC PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END EC PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard let keyData = Data(base64Encoded: cleanedKey) else {
            throw MatchError.apiAuthenticationFailed
        }

        do {
            self.privateKey = try P256.Signing.PrivateKey(derRepresentation: keyData)
        } catch {
            throw MatchError.apiAuthenticationFailed
        }
    }

    /// Generates a JWT token valid for 20 minutes
    /// - Returns: JWT token string
    /// - Throws: If token generation fails
    public func generateToken() throws -> String {
        let now = Date()
        let expiration = now.addingTimeInterval(20 * 60) // 20 minutes

        // Create JWT header
        let header = JWTHeader(
            alg: "ES256",
            kid: keyId,
            typ: "JWT"
        )

        // Create JWT payload
        let payload = JWTPayload(
            iss: issuerId,
            iat: Int(now.timeIntervalSince1970),
            exp: Int(expiration.timeIntervalSince1970),
            aud: "appstoreconnect-v1"
        )

        // Encode header and payload
        let headerData = try JSONEncoder().encode(header)
        let payloadData = try JSONEncoder().encode(payload)

        let headerBase64 = headerData.base64URLEncodedString()
        let payloadBase64 = payloadData.base64URLEncodedString()

        let signingInput = "\(headerBase64).\(payloadBase64)"

        // Sign with ES256
        guard let signingData = signingInput.data(using: .utf8) else {
            throw MatchError.apiAuthenticationFailed
        }

        let signature = try privateKey.signature(for: signingData)
        let signatureBase64 = signature.rawRepresentation.base64URLEncodedString()

        return "\(signingInput).\(signatureBase64)"
    }
}

// MARK: - JWT Models

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

// MARK: - Base64 URL Encoding

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
