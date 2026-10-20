import Foundation

// Stored in SwiftData as `String` raw values so they stay predicate-friendly
// and schema changes stay additive (unknown values decode to a fallback).

public enum AccountKind: String, Codable, Sendable, CaseIterable {
    case checking, savings, creditCard, cash, digitalWallet, loan, investment
}

public enum TransactionKind: String, Codable, Sendable, CaseIterable {
    case expense, income, transfer, adjustment
}

public enum TransactionSource: String, Codable, Sendable, CaseIterable {
    case manual, quickLog, snap, csvImport, aggregator, recurring, installment
}

public enum CategoryKind: String, Codable, Sendable, CaseIterable {
    case expense, income, transfer
}

public enum BudgetPeriod: String, Codable, Sendable, CaseIterable {
    case weekly, payCycle, monthly, yearly
}

public enum RecurrenceFrequency: String, Codable, Sendable, CaseIterable {
    case daily, weekly, biweekly, monthly, bimonthly, quarterly, yearly
}

/// Israeli installment flavours.
/// - `tashlumim`: regular interest-free installments set by the merchant.
/// - `credit`: "תשלומי קרדיט" — issuer-financed, usually with interest.
/// - `deferred`: single deferred charge ("דחוי").
public enum InstallmentKind: String, Codable, Sendable, CaseIterable {
    case tashlumim, credit, deferred
}

public enum CardIssuer: String, Codable, Sendable, CaseIterable {
    case isracard, max, cal, amex, diners, visaOther, mastercardOther, other
}

public enum ReceiptStatus: String, Codable, Sendable, CaseIterable {
    case processing, needsReview, ready, matched, discarded
}

public enum SyncState: String, Codable, Sendable, CaseIterable {
    case pending, sent, confirmed, failed
}

public enum LedgerOperation: String, Codable, Sendable, CaseIterable {
    case create, update, delete
}
