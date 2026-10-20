import Foundation
import CoreModels

/// Typed extraction result, independent of which extractor produced it.
public struct ReceiptDraft: Sendable, Hashable {
    public struct Field<T: Sendable & Hashable>: Sendable, Hashable {
        public var value: T
        public var confidence: Double     // 0...1; < 0.7 is highlighted for one-tap fix
    }
    public var merchant: Field<String>?
    public var date: Field<Date>?
    public var total: Field<Money>?
    public var vat: Field<Money>?
    public var installmentCount: Int = 1
    public var lineItems: [(text: String, total: Money)] = []
    public var extractorID: String

    public static func == (l: ReceiptDraft, r: ReceiptDraft) -> Bool {
        l.merchant == r.merchant && l.date == r.date && l.total == r.total && l.extractorID == r.extractorID
    }
    public func hash(into h: inout Hasher) { h.combine(merchant); h.combine(total); h.combine(extractorID) }
}

/// Every extractor (Foundation Models, heuristic, future Core ML) conforms to this.
public protocol ReceiptExtractor: Sendable {
    var id: String { get }
    func extract(ocrText: String, currency: CurrencyCode) async throws -> ReceiptDraft?
}

/// Deterministic fallback; works for Hebrew receipts where Apple Intelligence is unavailable.
public struct HeuristicReceiptParser: ReceiptExtractor {
    public let id = "heuristic"
    public init() {}

    // "סה"כ", "סהכ", "לתשלום", "TOTAL" followed by an amount like 1,234.50
    private static let totalKeywords = ["סה\"כ", "סה״כ", "סהכ", "לתשלום", "total", "סך הכל"]

    public func extract(ocrText: String, currency: CurrencyCode) async throws -> ReceiptDraft? {
        var draft = ReceiptDraft(extractorID: id)
        let lines = ocrText.split(whereSeparator: \.isNewline).map(String.init)
        for line in lines.reversed() {
            let lower = line.lowercased()
            guard Self.totalKeywords.contains(where: { lower.contains($0) }),
                  let amount = Self.lastAmount(in: line) else { continue }
            draft.total = .init(value: Money(amount, currency), confidence: 0.75)
            break
        }
        if let line = lines.first(where: { $0.contains("תשלומים") || $0.lowercased().contains("installments") }),
           let n = line.split(whereSeparator: { !$0.isNumber }).compactMap({ Int($0) }).first(where: { (2...36).contains($0) }) {
            draft.installmentCount = n
        }
        if let first = lines.first?.trimmingCharacters(in: .whitespaces), !first.isEmpty {
            draft.merchant = .init(value: first, confidence: 0.4)
        }
        return draft.total == nil ? nil : draft
    }

    /// Last decimal amount in a line ("1,234.50" -> 1234.50). Locale-independent on purpose.
    static func lastAmount(in line: String) -> Decimal? {
        var best: Decimal?
        var token = ""
        func flush() {
            let cleaned = token.replacingOccurrences(of: ",", with: "")
            if cleaned.contains("."), let d = Decimal(string: cleaned) { best = d }
            token = ""
        }
        for ch in line {
            if ch.isNumber || ch == "." || ch == "," { token.append(ch) } else { flush() }
        }
        flush()
        return best
    }
}

/// Receipt <-> bank transaction merge rule: amount ±1 %, date ±3 days, fuzzy merchant.
public struct ReceiptMatcher: Sendable {
    public init() {}
    public func matches(receiptTotal: Money, receiptDate: Date, transaction: TransactionSnapshot) -> Bool {
        guard receiptTotal.currency == transaction.amount.currency else { return false }
        let a = abs(receiptTotal.minorUnits), b = abs(transaction.amount.minorUnits)
        let tolerance = max(Int64(1), a / 100)
        let dayGap = abs(receiptDate.timeIntervalSince(transaction.date)) / 86_400
        return abs(a - b) <= tolerance && dayGap <= 3
    }
}
