import Foundation
import Testing
import CoreModels
@testable import Snap

@Suite struct SnapTests {
    @Test func hebrewTotal() async throws {
        let text = "שופרסל דיל\nחלב 6.90\nלחם 12.50\nסה\"כ לתשלום 1,219.40\n3 תשלומים"
        let d = try await HeuristicReceiptParser().extract(ocrText: text, currency: .ils)
        #expect(d?.total?.value == Money(Decimal(string: "1219.40")!, .ils))
        #expect(d?.installmentCount == 3)
    }
    @Test func matcherTolerance() {
        let t = TransactionSnapshot(id: UUID(), date: .now, settlementDate: nil, amount: Money(-100, .ils),
                                    kind: .expense, categoryID: nil, accountID: nil, merchantName: nil)
        #expect(ReceiptMatcher().matches(receiptTotal: Money(Decimal(string: "100.90")!, .ils), receiptDate: .now, transaction: t))
        #expect(!ReceiptMatcher().matches(receiptTotal: Money(105, .ils), receiptDate: .now, transaction: t))
    }
}
