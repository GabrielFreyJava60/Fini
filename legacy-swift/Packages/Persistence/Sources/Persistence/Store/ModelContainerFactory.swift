import Foundation
import SwiftData

public enum ModelContainerFactory {
    /// App Group shared by the app, widget extension and intents (quick-log writes from widgets).
    public static let appGroupID = "group.com.gabrielfreidlin.finance"

    public enum Location: Sendable {
        case appGroup
        case inMemory          // tests, previews
        case url(URL)
    }

    public static func make(_ location: Location = .appGroup) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration: ModelConfiguration
        switch location {
        case .inMemory:
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        case .url(let url):
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        case .appGroup:
            // Automatic CloudKit mirroring stays OFF: it would upload plaintext fields.
            // Vault sync goes through CKSyncEngine with client-side encryption instead.
            configuration = ModelConfiguration(
                "Ledger",
                schema: schema,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .none
            )
        }
        let container = try ModelContainer(
            for: schema,
            migrationPlan: LedgerMigrationPlan.self,
            configurations: [configuration]
        )
        #if os(iOS)
        if case .appGroup = location {
            try? applyFileProtection(to: configuration.url)
        }
        #endif
        return container
    }

    #if os(iOS)
    /// NSFileProtectionComplete on the store and its WAL/SHM siblings.
    /// NOTE: Complete protection means widgets/intents cannot open the store while the
    /// device is locked; quick-log from the Lock Screen goes through `QuickLogOutbox`
    /// (CompleteUntilFirstUserAuthentication, append-only) and is reconciled on unlock.
    static func applyFileProtection(to storeURL: URL) throws {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            guard fm.fileExists(atPath: url.path) else { continue }
            try fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        }
    }
    #endif
}
