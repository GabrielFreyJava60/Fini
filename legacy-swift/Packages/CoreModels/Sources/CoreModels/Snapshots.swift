import Foundation

/// Sendable value snapshots that cross actor / module boundaries.
/// SwiftData `@Model` objects never leave the Persistence module's actors.

public struct TransactionSnapshot: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let date: Date
    public let settlementDate: Date?
    public let amount: Money          // signed: negative = outflow
    public let kind: TransactionKind
    public let categoryID: UUID?
    public let accountID: UUID?
    public let merchantName: String?

    public init(id: UUID, date: Date, settlementDate: Date?, amount: Money, kind: TransactionKind,
                categoryID: UUID?, accountID: UUID?, merchantName: String?) {
        self.id = id; self.date = date; self.settlementDate = settlementDate; self.amount = amount
        self.kind = kind; self.categoryID = categoryID; self.accountID = accountID; self.merchantName = merchantName
    }
}

/// What the quick-log path writes. Small on purpose: no ledger load needed.
public struct QuickLogDraft: Hashable, Codable, Sendable {
    public var amount: Money
    public var categoryID: UUID?
    public var accountID: UUID?
    public var note: String?
    public var date: Date

    public init(amount: Money, categoryID: UUID? = nil, accountID: UUID? = nil, note: String? = nil, date: Date = .now) {
        self.amount = amount; self.categoryID = categoryID; self.accountID = accountID; self.note = note; self.date = date
    }
}

/// Minimal read-only snapshot shared with widgets via the App Group. Never the full ledger.
public struct WidgetSnapshot: Hashable, Codable, Sendable {
    public var safeToSpendToday: Money
    public var stressIndex: Int?          // 0...100, nil while "learning"
    public var nextPayday: Date?
    public var runwayP10: [Decimal]
    public var runwayP50: [Decimal]
    public var runwayP90: [Decimal]
    public var generatedAt: Date

    public init(safeToSpendToday: Money, stressIndex: Int?, nextPayday: Date?,
                runwayP10: [Decimal] = [], runwayP50: [Decimal] = [], runwayP90: [Decimal] = [], generatedAt: Date = .now) {
        self.safeToSpendToday = safeToSpendToday; self.stressIndex = stressIndex; self.nextPayday = nextPayday
        self.runwayP10 = runwayP10; self.runwayP50 = runwayP50; self.runwayP90 = runwayP90; self.generatedAt = generatedAt
    }

    public static let placeholder = WidgetSnapshot(safeToSpendToday: .zero(), stressIndex: nil, nextPayday: nil)
}
