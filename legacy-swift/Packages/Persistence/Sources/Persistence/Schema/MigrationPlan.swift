import SwiftData

/// Migration plan. Rules (ARCHITECTURE.md §4.5):
/// 1. Never edit a shipped SchemaVn. Copy it to SchemaVn+1, change the copy, repoint the typealiases.
/// 2. Prefer additive changes (new optional / defaulted properties) -> `.lightweight` stage.
/// 3. Renames use `@Attribute(originalName:)`; data reshapes use `.custom(willMigrate:didMigrate:)`.
/// 4. Sync payloads are versioned separately (SyncVault `payloadVersion`), so old devices
///    can ignore unknown fields from newer ones.
///
/// Template for the first change:
/// ```swift
/// public enum SchemaV2: VersionedSchema {
///     public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
///     public static var models: [any PersistentModel.Type] { [ /* V2 models */ ] }
///     // ... copied models with e.g. `public var tags: [String] = []` added to LedgerTransaction
/// }
/// static let migrateV1toV2 = MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
/// ```
public enum LedgerMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
