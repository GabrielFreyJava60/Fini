import Foundation
import CoreModels

/// Engine-agnostic boundary. Features depend on this, never on SwiftData directly,
/// so the week-1 benchmark can swap the analytics read model to Core Data / GRDB.
public protocol LedgerRepository: Sendable {
    func log(_ draft: QuickLogDraft) async throws -> UUID
    func transactions(from start: Date, to end: Date) async throws -> [TransactionSnapshot]
    func softDelete(transactionID: UUID) async throws
    func monthlySpendByCategory(month: Date, calendar: Calendar) async throws -> [UUID?: Money]
}

public enum LedgerError: Error, Equatable, Sendable {
    case notFound(UUID)
    case splitsDoNotSumToParent(expected: Int64, actual: Int64)
    case currencyMismatch
}
