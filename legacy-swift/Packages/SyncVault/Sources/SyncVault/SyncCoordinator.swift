import Foundation
import CloudKit
import CoreModels

/// Abstracts the local side so SyncVault doesn't import SwiftData models directly
/// (Persistence provides the conforming type; tests use an in-memory fake).
public protocol SyncLocalStore: Sendable {
    /// Pending outbound changes: (entityType, id, plaintext JSON, hlc, tombstone)
    func pendingChanges() async throws -> [OutboundChange]
    func markSent(_ ids: [CKRecord.ID]) async throws
    /// Field-level LWW merge of a decrypted inbound payload.
    func merge(entityType: String, id: UUID, payload: Data, hlc: HLCTimestamp, tombstone: Bool) async throws
    func loadSyncState() async -> CKSyncEngine.State.Serialization?
    func saveSyncState(_ state: CKSyncEngine.State.Serialization) async
}

public struct OutboundChange: Sendable {
    public var entityType: String
    public var id: UUID
    public var payload: Data
    public var hlc: HLCTimestamp
    public var tombstone: Bool
    public init(entityType: String, id: UUID, payload: Data, hlc: HLCTimestamp, tombstone: Bool) {
        self.entityType = entityType; self.id = id; self.payload = payload; self.hlc = hlc; self.tombstone = tombstone
    }
}

/// CKSyncEngine delegate. Zero-knowledge: encrypt before `nextRecordZoneChangeBatch`,
/// decrypt in `fetchedRecordZoneChanges`.
public actor SyncCoordinator: CKSyncEngineDelegate {
    public static let payloadVersion = 1

    private let store: any SyncLocalStore
    private let crypto: VaultCrypto
    private var engine: CKSyncEngine?

    public init(store: any SyncLocalStore, crypto: VaultCrypto) {
        self.store = store
        self.crypto = crypto
    }

    public func start(container: CKContainer = .default()) async {
        var config = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: await store.loadSyncState(),
            delegate: self
        )
        config.automaticallySync = true
        let engine = CKSyncEngine(config)
        self.engine = engine
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: RecordMapper.zoneID))])
    }

    /// Call after every local ledger write (debounced by the caller).
    public func enqueueLocalChanges() async throws {
        guard let engine else { return }
        let changes = try await store.pendingChanges()
        engine.state.add(pendingRecordZoneChanges: changes.map {
            .saveRecord(RecordMapper.recordID(entityType: $0.entityType, id: $0.id))
        })
    }

    // MARK: CKSyncEngineDelegate

    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            await store.saveSyncState(update.stateSerialization)
        case .fetchedRecordZoneChanges(let changes):
            for modification in changes.modifications {
                let record = modification.record
                let parts = record.recordID.recordName.split(separator: ".", maxSplits: 1).map(String.init)
                guard parts.count == 2, let id = UUID(uuidString: parts[1]),
                      let decoded = try? RecordMapper.envelope(from: record),
                      let plaintext = try? crypto.open(decoded.0, recordType: RecordMapper.recordType,
                                                       recordName: record.recordID.recordName)
                else { continue } // unknown key / corrupt: quarantine + surface in Settings (TODO)
                try? await store.merge(entityType: parts[0], id: id, payload: plaintext, hlc: decoded.1, tombstone: decoded.2)
            }
        case .sentRecordZoneChanges(let sent):
            try? await store.markSent(sent.savedRecords.map(\.recordID))
            // failedRecordSaves: .serverRecordChanged -> merge server copy via HLC LWW, re-enqueue.
        default:
            break
        }
    }

    public func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        guard !pending.isEmpty, let outbound = try? await store.pendingChanges() else { return nil }
        let byName = Dictionary(outbound.map { (RecordMapper.recordID(entityType: $0.entityType, id: $0.id).recordName, $0) },
                                uniquingKeysWith: { a, b in a.hlc > b.hlc ? a : b })
        let crypto = self.crypto
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            guard let change = byName[recordID.recordName],
                  let env = try? crypto.seal(change.payload, recordType: RecordMapper.recordType,
                                             recordName: recordID.recordName, payloadVersion: Self.payloadVersion)
            else { return nil }
            let record = CKRecord(recordType: RecordMapper.recordType, recordID: recordID)
            RecordMapper.apply(env, hlc: change.hlc, tombstone: change.tombstone, to: record)
            return record
        }
    }
}
