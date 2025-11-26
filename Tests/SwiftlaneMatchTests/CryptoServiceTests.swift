import Testing
import Foundation
@testable import SwiftlaneMatch

@Suite("CryptoService Tests")
struct CryptoServiceTests {
    let service = CryptoService()

    @Test("Encrypt and decrypt roundtrip with simple data")
    func testEncryptDecryptRoundtrip() async throws {
        let originalData = "Hello, Swiftlane Match!".data(using: .utf8)!
        let password = "test_password_123"

        let encrypted = try await service.encrypt(data: originalData, password: password)
        let decrypted = try await service.decrypt(data: encrypted, password: password)

        #expect(decrypted == originalData)
    }

    @Test("Encrypt and decrypt roundtrip with empty data")
    func testEncryptDecryptEmptyData() async throws {
        let originalData = Data()
        let password = "test_password_123"

        let encrypted = try await service.encrypt(data: originalData, password: password)
        let decrypted = try await service.decrypt(data: encrypted, password: password)

        #expect(decrypted == originalData)
        #expect(decrypted.count == 0)
    }

    @Test("Encrypt and decrypt roundtrip with binary data")
    func testEncryptDecryptBinaryData() async throws {
        // Create some binary data
        let originalData = Data([0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD, 0x48, 0x65, 0x6C, 0x6C, 0x6F])
        let password = "binary_test_password"

        let encrypted = try await service.encrypt(data: originalData, password: password)
        let decrypted = try await service.decrypt(data: encrypted, password: password)

        #expect(decrypted == originalData)
    }

    @Test("Encrypt and decrypt roundtrip with large data")
    func testEncryptDecryptLargeData() async throws {
        // Create 1MB of random data
        let originalData = Data((0..<1024*1024).map { _ in UInt8.random(in: 0...255) })
        let password = "large_data_password"

        let encrypted = try await service.encrypt(data: originalData, password: password)
        let decrypted = try await service.decrypt(data: encrypted, password: password)

        #expect(decrypted == originalData)
    }

    @Test("Decrypt with wrong password throws invalidPassword error")
    func testDecryptWithWrongPassword() async throws {
        let originalData = "Secret data".data(using: .utf8)!
        let correctPassword = "correct_password"
        let wrongPassword = "wrong_password"

        let encrypted = try await service.encrypt(data: originalData, password: correctPassword)

        do {
            _ = try await service.decrypt(data: encrypted, password: wrongPassword)
            Issue.record("Expected invalidPassword error to be thrown")
        } catch MatchError.invalidPassword {
            // Success - expected error was thrown
        } catch {
            Issue.record("Expected invalidPassword error, got \(error)")
        }
    }

    @Test("Decrypt with modified ciphertext throws error")
    func testDecryptWithModifiedCiphertext() async throws {
        let originalData = "Tamper test data".data(using: .utf8)!
        let password = "test_password"

        var encrypted = try await service.encrypt(data: originalData, password: password)

        // Modify a byte in the ciphertext (after salt and IV)
        let modifyIndex = 20 + (encrypted.count - 20) / 2
        encrypted[modifyIndex] ^= 0xFF

        do {
            _ = try await service.decrypt(data: encrypted, password: password)
            Issue.record("Expected error to be thrown for modified ciphertext")
        } catch is MatchError {
            // Success - expected error was thrown
        } catch {
            Issue.record("Expected MatchError, got \(error)")
        }
    }

    @Test("Decrypt with too short data throws decryptionFailed error")
    func testDecryptWithTooShortData() async throws {
        let tooShortData = Data([0x01, 0x02, 0x03]) // Only 3 bytes, need at least 44
        let password = "test_password"

        do {
            _ = try await service.decrypt(data: tooShortData, password: password)
            Issue.record("Expected decryptionFailed error to be thrown")
        } catch MatchError.decryptionFailed(let message) {
            #expect(message.contains("Invalid encrypted data: too short"))
        } catch {
            Issue.record("Expected decryptionFailed error, got \(error)")
        }
    }

    @Test("Encrypted data has correct format structure")
    func testEncryptedDataFormat() async throws {
        let originalData = "Format test".data(using: .utf8)!
        let password = "test_password"

        let encrypted = try await service.encrypt(data: originalData, password: password)

        // Verify minimum length: salt(16) + nonce(12) + tag(16) + at least some ciphertext
        #expect(encrypted.count >= 44 + originalData.count)

        // Verify the encrypted data is different from original
        #expect(encrypted != originalData)
    }

    @Test("Same data with different passwords produces different ciphertext")
    func testDifferentPasswordsDifferentCiphertext() async throws {
        let originalData = "Same data".data(using: .utf8)!
        let password1 = "password_one"
        let password2 = "password_two"

        let encrypted1 = try await service.encrypt(data: originalData, password: password1)
        let encrypted2 = try await service.encrypt(data: originalData, password: password2)

        // Different passwords should produce different ciphertexts
        #expect(encrypted1 != encrypted2)

        // Both should decrypt correctly with their respective passwords
        let decrypted1 = try await service.decrypt(data: encrypted1, password: password1)
        let decrypted2 = try await service.decrypt(data: encrypted2, password: password2)

        #expect(decrypted1 == originalData)
        #expect(decrypted2 == originalData)
    }

    @Test("Multiple encryptions of same data produce different ciphertexts")
    func testMultipleEncryptionsDifferentCiphertexts() async throws {
        let originalData = "Deterministic test".data(using: .utf8)!
        let password = "same_password"

        let encrypted1 = try await service.encrypt(data: originalData, password: password)
        let encrypted2 = try await service.encrypt(data: originalData, password: password)

        // Due to random salt and IV, same data+password should produce different ciphertexts
        #expect(encrypted1 != encrypted2)

        // Both should decrypt to the same original data
        let decrypted1 = try await service.decrypt(data: encrypted1, password: password)
        let decrypted2 = try await service.decrypt(data: encrypted2, password: password)

        #expect(decrypted1 == originalData)
        #expect(decrypted2 == originalData)
    }

    @Test("Decrypt with corrupt salt section")
    func testDecryptWithCorruptSalt() async throws {
        let originalData = "Salt corruption test".data(using: .utf8)!
        let password = "test_password"

        var encrypted = try await service.encrypt(data: originalData, password: password)

        // Corrupt the salt (first 16 bytes)
        encrypted[0] ^= 0xFF

        // Should fail with invalidPassword or keyDerivationFailed
        do {
            _ = try await service.decrypt(data: encrypted, password: password)
            Issue.record("Expected error to be thrown for corrupt salt")
        } catch is MatchError {
            // Success - expected error was thrown
        } catch {
            Issue.record("Expected MatchError, got \(error)")
        }
    }

    @Test("Decrypt with corrupt nonce section")
    func testDecryptWithCorruptNonce() async throws {
        let originalData = "Nonce corruption test".data(using: .utf8)!
        let password = "test_password"

        var encrypted = try await service.encrypt(data: originalData, password: password)

        // Corrupt the nonce (bytes 16-27)
        encrypted[20] ^= 0xFF

        // Should fail decryption
        do {
            _ = try await service.decrypt(data: encrypted, password: password)
            Issue.record("Expected error to be thrown for corrupt IV")
        } catch is MatchError {
            // Success - expected error was thrown
        } catch {
            Issue.record("Expected MatchError, got \(error)")
        }
    }

    @Test("Decrypt with corrupt tag section")
    func testDecryptWithCorruptTag() async throws {
        let originalData = "Tag corruption test".data(using: .utf8)!
        let password = "test_password"

        var encrypted = try await service.encrypt(data: originalData, password: password)

        // Corrupt the tag (last 16 bytes)
        encrypted[encrypted.count - 1] ^= 0xFF

        // Should fail authentication
        do {
            _ = try await service.decrypt(data: encrypted, password: password)
            Issue.record("Expected error to be thrown for corrupt tag")
        } catch is MatchError {
            // Success - expected error was thrown
        } catch {
            Issue.record("Expected MatchError, got \(error)")
        }
    }

    @Test("Password with special characters")
    func testPasswordWithSpecialCharacters() async throws {
        let originalData = "Special chars test".data(using: .utf8)!
        let password = "p@ssw0rd!#$%^&*()_+-=[]{}|;':\",./<>?`~"

        let encrypted = try await service.encrypt(data: originalData, password: password)
        let decrypted = try await service.decrypt(data: encrypted, password: password)

        #expect(decrypted == originalData)
    }

    @Test("Password with Unicode characters")
    func testPasswordWithUnicodeCharacters() async throws {
        let originalData = "Unicode test".data(using: .utf8)!
        let password = "пароль密码🔐🔑"

        let encrypted = try await service.encrypt(data: originalData, password: password)
        let decrypted = try await service.decrypt(data: encrypted, password: password)

        #expect(decrypted == originalData)
    }

    @Test("Very long password")
    func testVeryLongPassword() async throws {
        let originalData = "Long password test".data(using: .utf8)!
        let password = String(repeating: "a", count: 1000)

        let encrypted = try await service.encrypt(data: originalData, password: password)
        let decrypted = try await service.decrypt(data: encrypted, password: password)

        #expect(decrypted == originalData)
    }

    @Test("Data with only null bytes")
    func testDataWithNullBytes() async throws {
        let originalData = Data(repeating: 0x00, count: 100)
        let password = "null_bytes_password"

        let encrypted = try await service.encrypt(data: originalData, password: password)
        let decrypted = try await service.decrypt(data: encrypted, password: password)

        #expect(decrypted == originalData)
    }
}
