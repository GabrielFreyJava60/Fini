import Foundation
import CloudKit
import CoreModels

/// Maps encrypted envelopes <-> CKRecords in the private DB custom zone "LedgerZone".
///
/// CKRecord layout (every syncable entity, one record type per entity):
/// | field           | type   | encrypted?                     |
/// |-----------------|--------|--------------------------------|
/// | recordName      | String | "<entityType>.<uuid>" (opaque) |
/// | payload         | Bytes  | AES-GCM (client-side)          |
/// | keyID           | String | CloudKit encryptedValues       |
/// | payloadVersion  | Int64  | CloudKit encryptedValues       |
/// | hlc             | String | CloudKit encryptedValues       |
/// | tombstone       | Int64  | plaintext 0/1 (no financial info) |
/// No amounts, merchants, dates or names are ever stored outside `payload`.
public enum RecordMapper {
    public static let zoneID = CKRecordZone.ID(zoneName: "LedgerZone", ownerName: CKCurrentUserDefaultName)
    /// Single opaque record type so CloudKit schema never reveals which entity is which.
    public static let recordType = "VaultRecord"

    public static func recordID(entityType: String, id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "\(entityType).\(id.uuidString)", zoneID: zoneID)
    }

    public static func apply(_ env: EncryptedEnvelope, hlc: HLCTimestamp, tombstone: Bool, to record: CKRecord) {
        record["payload"] = env.sealed as NSData
        record["tombstone"] = (tombstone ? 1 : 0) as NSNumber
        record.encryptedValues["keyID"] = env.keyID
        record.encryptedValues["payloadVersion"] = Int64(env.payloadVersion)
        record.encryptedValues["hlc"] = hlc.description
    }

    public static func envelope(from record: CKRecord) throws -> (EncryptedEnvelope, HLCTimestamp, Bool) {
        guard
            let sealed = record["payload"] as? Data,
            let keyID = record.encryptedValues["keyID"] as? String,
            let version = record.encryptedValues["payloadVersion"] as? Int64,
            let hlcString = record.encryptedValues["hlc"] as? String,
            let hlc = HLCTimestamp(hlcString)
        else { throw VaultError.malformedEnvelope }
        let tombstone = (record["tombstone"] as? Int64 ?? 0) == 1
        return (EncryptedEnvelope(payloadVersion: Int(version), keyID: keyID, sealed: sealed), hlc, tombstone)
    }
}
