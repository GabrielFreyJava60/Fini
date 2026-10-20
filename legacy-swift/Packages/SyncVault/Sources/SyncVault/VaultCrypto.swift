import Foundation
import CryptoKit

/// Encrypted payload for one ledger entity. This is ALL that reaches CloudKit.
public struct EncryptedEnvelope: Codable, Sendable, Hashable {
    /// Bump when the plaintext payload schema changes (independent of SwiftData schema versions).
    public var payloadVersion: Int
    /// Identifies which DEK sealed this (supports key rotation).
    public var keyID: String
    /// AES-GCM combined representation: nonce (12) || ciphertext || tag (16).
    public var sealed: Data
}

public enum VaultError: Error, Sendable {
    case unknownKey(String)
    case malformedEnvelope
}

/// Key hierarchy:
///   recovery phrase (user-held, 24 words) --HKDF-SHA256--> KEK
///   KEK --AES-KeyWrap--> wrapped DEK (stored in iCloud Keychain, kSecAttrSynchronizable)
///   DEK (AES-256) --AES-GCM--> record payloads
/// The Secure Enclave key only wraps the *local* DEK cache; it cannot sync.
public struct VaultCrypto: Sendable {
    public let keyID: String
    private let dek: SymmetricKey

    public init(keyID: String, dek: SymmetricKey) {
        self.keyID = keyID
        self.dek = dek
    }

    public static func newDEK() -> SymmetricKey { SymmetricKey(size: .bits256) }

    public static func deriveKEK(fromRecoverySeed seed: Data, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: seed),
            salt: salt,
            info: Data("finance.vault.kek.v1".utf8),
            outputByteCount: 32
        )
    }

    public static func wrap(dek: SymmetricKey, with kek: SymmetricKey) throws -> Data {
        try AES.KeyWrap.wrap(dek, using: kek)
    }

    public static func unwrap(_ wrapped: Data, with kek: SymmetricKey) throws -> SymmetricKey {
        try AES.KeyWrap.unwrap(wrapped, using: kek)
    }

    /// AAD binds ciphertext to its record identity, so a server can't swap payloads between records.
    static func aad(recordType: String, recordName: String, payloadVersion: Int) -> Data {
        Data("\(recordType)|\(recordName)|v\(payloadVersion)".utf8)
    }

    public func seal(_ plaintext: Data, recordType: String, recordName: String, payloadVersion: Int) throws -> EncryptedEnvelope {
        let box = try AES.GCM.seal(plaintext, using: dek,
                                   authenticating: Self.aad(recordType: recordType, recordName: recordName, payloadVersion: payloadVersion))
        guard let combined = box.combined else { throw VaultError.malformedEnvelope }
        return EncryptedEnvelope(payloadVersion: payloadVersion, keyID: keyID, sealed: combined)
    }

    public func open(_ envelope: EncryptedEnvelope, recordType: String, recordName: String) throws -> Data {
        guard envelope.keyID == keyID else { throw VaultError.unknownKey(envelope.keyID) }
        let box = try AES.GCM.SealedBox(combined: envelope.sealed)
        return try AES.GCM.open(box, using: dek,
                                authenticating: Self.aad(recordType: recordType, recordName: recordName, payloadVersion: envelope.payloadVersion))
    }
}
