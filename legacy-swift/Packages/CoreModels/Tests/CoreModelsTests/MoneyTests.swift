import Foundation
import Testing
@testable import CoreModels

@Suite struct MoneyTests {
    @Test func minorUnitsRoundTrip() {
        let m = Money(minorUnits: 12_840, currency: .ils)
        #expect(m.amount == Decimal(string: "128.4"))
        #expect(m.minorUnits == 12_840)
    }

    @Test func noFloatingPointDrift() throws {
        let a = Money(Decimal(string: "0.1")!, .ils)
        let b = Money(Decimal(string: "0.2")!, .ils)
        #expect(try a.adding(b).amount == Decimal(string: "0.3"))
    }

    @Test func currencyMismatchThrows() {
        #expect(throws: MoneyError.self) { try Money(1, .ils).adding(Money(1, .usd)) }
    }

    @Test(arguments: [1, 2, 3, 7, 12, 36])
    func allocationSumsExactly(count: Int) throws {
        let total = Money(Decimal(string: "4000.01")!, .ils)
        let parts = try total.allocate(into: count)
        #expect(parts.count == count)
        #expect(parts.reduce(Int64(0)) { $0 + $1.minorUnits } == total.minorUnits)
        let spread = parts.map(\.minorUnits).max()! - parts.map(\.minorUnits).min()!
        #expect(spread <= 1)
    }

    @Test func negativeAllocation() throws {
        let parts = try Money(minorUnits: -1000, currency: .ils).allocate(into: 3)
        #expect(parts.map(\.minorUnits) == [-334, -333, -333])
    }

    @Test func zeroDigitCurrency() {
        #expect(Money(minorUnits: 500, currency: "JPY").amount == 500)
        #expect(CurrencyCode("ils") == .ils)
    }
}

@Suite struct SettlementTests {
    var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        return c
    }
    func d(_ y: Int, _ m: Int, _ day: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: day))! }

    @Test func beforeCloseChargesNextMonth() {
        let rule = CardSettlementRule(chargeDay: 10, statementCloseDay: 31)
        #expect(rule.settlementDate(forPurchaseOn: d(2026, 10, 20), calendar: cal) == d(2026, 11, 10))
    }

    @Test func afterCloseRollsTwoMonths() {
        let rule = CardSettlementRule(chargeDay: 2, statementCloseDay: 25)
        #expect(rule.settlementDate(forPurchaseOn: d(2026, 12, 28), calendar: cal) == d(2027, 2, 2))
    }

    @Test func installmentSchedule() throws {
        let p = try InstallmentSchedule.payments(total: Money(4000, .ils), count: 3, firstChargeDate: d(2026, 11, 10), calendar: cal)
        #expect(p.map(\.amount.minorUnits) == [133_334, 133_333, 133_333])
        #expect(p.last?.dueDate == d(2027, 1, 10))
    }
}

@Suite struct HLCTests {
    @Test func monotonicUnderFrozenClock() async {
        let clock = HybridLogicalClock(node: "A", now: { 1_000 })
        let a = await clock.tick()
        let b = await clock.tick()
        #expect(a < b)
        #expect(HLCTimestamp(b.description) == b)
    }

    @Test func receiveAdvancesPastRemote() async {
        let clock = HybridLogicalClock(node: "A", now: { 1_000 })
        let remote = HLCTimestamp(millis: 5_000, counter: 3, node: "B")
        let merged = await clock.receive(remote)
        #expect(merged > remote)
    }
}
