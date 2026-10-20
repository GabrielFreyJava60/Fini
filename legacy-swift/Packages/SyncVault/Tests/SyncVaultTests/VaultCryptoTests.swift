import Foundation
import CryptoKit
import Testing
@testable import SyncVault

@Suite struct VaultCryptoTests {
    @Test func roundTrip() throws {
        let crypto = VaultCrypto(keyID: "k1", dek: VaultCrypto.newDEK())
        let env = try crypto.seal(Data("₪45 groceries".utf8), recordType: "VaultRecord", recordName: "LedgerTransaction.x", payloadVersion: 1)
        #expect(try crypto.open(env, recordType: "VaultRecord", recordName: "LedgerTransaction.x") == Data("₪45 groceries".utf8))
    }

    @Test func aadPreventsRecordSwap() throws {
        let crypto = VaultCrypto(keyID: "k1", dek: VaultCrypto.newDEK())
        let env = try crypto.seal(Data("a".utf8), recordType: "VaultRecord", recordName: "A", payloadVersion: 1)
        #expect(throws: (any Error).self) { try crypto.open(env, recordType: "VaultRecord", recordName: "B") }
    }

    @Test func keyWrapRoundTrip() throws {
        let kek = VaultCrypto.deriveKEK(fromRecoverySeed: Data(repeating: 7, count: 32), salt: Data("salt".utf8))
        let dek = VaultCrypto.newDEK()
        let wrapped = try VaultCrypto.wrap(dek: dek, with: kek)
        let unwrapped = try VaultCrypto.unwrap(wrapped, with: kek)
        #expect(unwrapped.withUnsafeBytes { Data($0) } == dek.withUnsafeBytes { Data($0) })
    }
}
