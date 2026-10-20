import Foundation
import Testing
import SwiftData
import CoreModels
@testable import Persistence

@Suite struct SchemaTests {
    @Test func containerBuildsInMemory() throws {
        _ = try ModelContainerFactory.make(.inMemory)
    }

    @Test func quickLogRoundTrip() async throws {
        let container = try ModelContainerFactory.make(.inMemory)
        let ledger = LedgerActor(modelContainer: container)
        let id = try await ledger.log(QuickLogDraft(amount: Money(-45, .ils)))
        let rows = try await ledger.transactions(from: .distantPast, to: .distantFuture)
        #expect(rows.map(\.id) == [id])
        #expect(rows.first?.amount == Money(-45, .ils))
    }

    @Test func splitsMustSum() async throws {
        let container = try ModelContainerFactory.make(.inMemory)
        let ledger = LedgerActor(modelContainer: container)
        let id = try await ledger.log(QuickLogDraft(amount: Money(-100, .ils)))
        await #expect(throws: LedgerError.self) {
            try await ledger.split(transactionID: id, into: [(Money(-60, .ils), nil), (Money(-30, .ils), nil)])
        }
        try await ledger.split(transactionID: id, into: [(Money(-60, .ils), nil), (Money(-40, .ils), nil)])
    }

    @Test func installmentPaymentsSumExactly() throws {
        let plan = InstallmentPlan(title: "Laptop", purchaseDate: .now, firstChargeDate: .now,
                                   total: Money(Decimal(string: "4000.01")!, .ils), paymentCount: 3)
        try plan.generatePayments(calendar: .current)
        #expect(plan.payments.reduce(Int64(0)) { $0 + $1.amountMinor } == plan.totalMinor)
    }
}
