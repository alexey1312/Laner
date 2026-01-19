import Crypto
import Foundation

/// Thread-safe cryptography service for encrypting and decrypting Match data.
///
/// This service provides AES-256-GCM encryption:
/// - Uses HKDF-SHA256 for key derivation (cross-platform via swift-crypto)
/// - Salt is 16 bytes prepended to the encrypted data
/// - Uses AES-256-GCM with 12-byte nonce
/// - Auth tag is 16 bytes appended to ciphertext
/// - File format: [salt:16][nonce:12][ciphertext][tag:16]
public actor CryptoService {
    private static let saltLength = 16
    private static let nonceLength = 12
    private static let tagLength = 16
    private static let keyLength = 32 // AES-256 requires 32 bytes

    public init() {}

    /// Encrypts data using AES-256-GCM with HKDF-derived key.
    ///
    /// - Parameters:
    ///   - data: The data to encrypt
    ///   - password: The password to derive the encryption key from
    /// - Returns: Encrypted data: [salt:16][nonce:12][ciphertext][tag:16]
    /// - Throws: `MatchError.encryptionFailed` if encryption fails
    public func encrypt(data: Data, password: String) async throws -> Data {
        guard let passwordData = password.data(using: .utf8) else {
            throw MatchError.encryptionFailed("Invalid password encoding")
        }

        // Generate random salt
        let salt = SymmetricKey(size: .bits128)
        let saltData = salt.withUnsafeBytes { Data($0) }

        // Derive key using HKDF-SHA256
        let inputKey = SymmetricKey(data: passwordData)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: saltData,
            info: Data("laner-match".utf8),
            outputByteCount: Self.keyLength
        )

        // Encrypt using AES-256-GCM (nonce is auto-generated)
        do {
            let sealedBox = try AES.GCM.seal(data, using: derivedKey)

            // Construct output: [salt:16][nonce:12][ciphertext][tag:16]
            var result = Data()
            result.append(saltData)
            result.append(contentsOf: sealedBox.nonce)
            result.append(sealedBox.ciphertext)
            result.append(sealedBox.tag)

            return result
        } catch {
            throw MatchError.encryptionFailed(error.localizedDescription)
        }
    }

    /// Decrypts data encrypted with AES-256-GCM using HKDF-derived key.
    ///
    /// - Parameters:
    ///   - data: The encrypted data: [salt:16][nonce:12][ciphertext][tag:16]
    ///   - password: The password to derive the decryption key from
    /// - Returns: Decrypted plaintext data
    /// - Throws: `MatchError.decryptionFailed` or `MatchError.invalidPassword` if decryption fails
    public func decrypt(data: Data, password: String) async throws -> Data {
        guard let passwordData = password.data(using: .utf8) else {
            throw MatchError.decryptionFailed("Invalid password encoding")
        }

        // Verify minimum length: salt(16) + nonce(12) + tag(16) = 44 bytes minimum
        let minimumLength = Self.saltLength + Self.nonceLength + Self.tagLength
        guard data.count >= minimumLength else {
            throw MatchError.decryptionFailed("Invalid encrypted data: too short")
        }

        // Extract components
        let salt = data.prefix(Self.saltLength)
        let nonceData = data.dropFirst(Self.saltLength).prefix(Self.nonceLength)
        let ciphertextAndTag = data.dropFirst(Self.saltLength + Self.nonceLength)

        guard ciphertextAndTag.count >= Self.tagLength else {
            throw MatchError.decryptionFailed("Invalid encrypted data: missing tag")
        }

        let ciphertext = ciphertextAndTag.dropLast(Self.tagLength)
        let tag = ciphertextAndTag.suffix(Self.tagLength)

        // Derive key using HKDF-SHA256
        let inputKey = SymmetricKey(data: passwordData)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: salt,
            info: Data("laner-match".utf8),
            outputByteCount: Self.keyLength
        )

        // Decrypt using AES-256-GCM
        do {
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            let plaintext = try AES.GCM.open(sealedBox, using: derivedKey)

            return plaintext
        } catch {
            // Check for authentication failure (wrong password/tampered data)
            // CryptoKitError doesn't conform to Equatable on older macOS, so check by description
            // On Linux with BoringSSL, the error may be underlyingCoreCryptoError instead
            let errorDescription = String(describing: error).lowercased()
            if errorDescription.contains("authenticationfailure") ||
                errorDescription.contains("authentication") ||
                errorDescription.contains("underlyingcorecryptoerror")
            {
                throw MatchError.invalidPassword
            }
            throw MatchError.decryptionFailed(error.localizedDescription)
        }
    }
}
