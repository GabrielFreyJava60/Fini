import Foundation
import SwiftData
import CoreModels

/// Single writer for the ledger. Every mutation also appends a `LedgerEvent`
/// (the sync + undo source of truth) in the same save.
@ModelActor
public actor LedgerActor: LedgerRepository {
    private static let deviceID = UUID().uuidString   // replaced by a persisted per-install ID in the app


    public func log(_ draft: QuickLogDraft) async throws -> UUID {
        let hlc = await sharedClock.tick().description
        let txn = LedgerTransaction(
            date: draft.date,
            amount: draft.amount,
            kind: draft.amount.isNegative ? .expense : .income,
            source: .quickLog,
            note: draft.note,
            hlc: hlc
        )
        if let categoryID = draft.categoryID {
            txn.category = try fetchOne(Category.self, id: categoryID)
        }
        if let accountID = draft.accountID, let account = try fetchOne(Account.self, id: accountID) {
            txn.account = account
            // Israeli card: cash leaves on the next charge day, not today.
            if account.kind == .creditCard, let cycle = account.billingCycle(on: draft.date) {
                txn.settlementDate = cycle.rule.settlementDate(forPurchaseOn: draft.date, calendar: .current)
            }
        }
        modelContext.insert(txn)
        try appendEvent(for: txn.id, type: "LedgerTransaction", op: .create, hlc: hlc,
                        fields: ["amountMinor": "\(txn.amountMinor)", "currencyCode": txn.currencyCode,
                                 "date": "\(txn.date.timeIntervalSince1970)"])
        try modelContext.save()
        return txn.id
    }

    public func transactions(from start: Date, to end: Date) async throws -> [TransactionSnapshot] {
        let descriptor = FetchDescriptor<LedgerTransaction>(
            predicate: #Predicate { !$0.isTombstoned && $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.snapshot)
    }

    public func softDelete(transactionID: UUID) async throws {
        guard let txn = try fetchOne(LedgerTransaction.self, id: transactionID) else {
            throw LedgerError.notFound(transactionID)
        }
        let hlc = await sharedClock.tick().description
        txn.isTombstoned = true
        txn.updatedHLC = hlc
        try appendEvent(for: transactionID, type: "LedgerTransaction", op: .delete, hlc: hlc, fields: [:])
        try modelContext.save()
    }

    /// In-memory reduction over an indexed date-range fetch. Week-1 spike target: < 50 ms @ 100k rows.
    public func monthlySpendByCategory(month: Date, calendar: Calendar) async throws -> [UUID?: Money] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [:] }
        let start = interval.start, end = interval.end
        let expense = TransactionKind.expense.rawValue
        var descriptor = FetchDescriptor<LedgerTransaction>(
            predicate: #Predicate { !$0.isTombstoned && $0.kindRaw == expense && $0.date >= start && $0.date < end }
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.category]
        var totals: [UUID?: Int64] = [:]
        var currency = CurrencyCode.default
        for txn in try modelContext.fetch(descriptor) {
            totals[txn.category?.id, default: 0] += txn.amountMinor
            currency = CurrencyCode(rawValue: txn.currencyCode) // assumes single base currency per ledger (MVP)
        }
        return totals.mapValues { Money(minorUnits: $0, currency: currency) }
    }

    /// Replaces a transaction's splits. Children must sum exactly to the parent.
    public func split(transactionID: UUID, into parts: [(Money, UUID?)]) async throws {
        guard let parent = try fetchOne(LedgerTransaction.self, id: transactionID) else {
            throw LedgerError.notFound(transactionID)
        }
        guard parts.allSatisfy({ $0.0.currency.rawValue == parent.currencyCode }) else { throw LedgerError.currencyMismatch }
        let sum = parts.reduce(Int64(0)) { $0 + $1.0.minorUnits }
        guard sum == parent.amountMinor else {
            throw LedgerError.splitsDoNotSumToParent(expected: parent.amountMinor, actual: sum)
        }
        let hlc = await sharedClock.tick().description
        for old in parent.splits { old.isTombstoned = true; old.updatedHLC = hlc }
        for (money, categoryID) in parts {
            let child = LedgerTransaction(date: parent.date, settlementDate: parent.settlementDate,
                                          amount: money, kind: parent.kind, source: parent.source, hlc: hlc)
            child.category = try categoryID.flatMap { try fetchOne(Category.self, id: $0) }
            child.splitParent = parent
            modelContext.insert(child)
        }
        try appendEvent(for: transactionID, type: "LedgerTransaction", op: .update, hlc: hlc, fields: ["splits": "\(parts.count)"])
        try modelContext.save()
    }

    // MARK: Helpers

    private func fetchOne<M: PersistentModel>(_ type: M.Type, id: UUID) throws -> M? where M: IdentifiedModel {
        var descriptor = FetchDescriptor<M>(predicate: M.predicate(id: id))
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func appendEvent(for id: UUID, type: String, op: LedgerOperation, hlc: String, fields: [String: String]) throws {
        let json = try JSONEncoder().encode(fields)
        modelContext.insert(LedgerEvent(entityType: type, entityID: id, operation: op, hlc: hlc,
                                        changedFieldsJSON: json, originDeviceID: Self.deviceID))
    }
}

/// Process-wide clock so every write on this device is totally ordered.
let sharedClock = HybridLogicalClock(node: UUID().uuidString)

/// Lets `fetchOne` build a typed `#Predicate` on `id` for each model.
public protocol IdentifiedModel {
    static func predicate(id: UUID) -> Predicate<Self>
}

extension Account: IdentifiedModel {
    public static func predicate(id: UUID) -> Predicate<Account> { #Predicate { $0.id == id } }
}
extension Category: IdentifiedModel {
    public static func predicate(id: UUID) -> Predicate<Category> { #Predicate { $0.id == id } }
}
extension LedgerTransaction: IdentifiedModel {
    public static func predicate(id: UUID) -> Predicate<LedgerTransaction> { #Predicate { $0.id == id } }
}
extension Merchant: IdentifiedModel {
    public static func predicate(id: UUID) -> Predicate<Merchant> { #Predicate { $0.id == id } }
}
