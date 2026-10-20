import Foundation

/// Israeli credit cards settle monthly on a fixed charge day (commonly 2, 10, 15).
/// Purchases made before the statement close day are charged on the next charge day;
/// purchases after it roll to the following month.
public struct CardSettlementRule: Hashable, Codable, Sendable {
    /// Day of month the bank account is debited (1...28).
    public var chargeDay: Int
    /// Last day of month (inclusive) whose purchases go on the upcoming charge.
    /// Many issuers close ~2-4 days before the charge day of the following month.
    public var statementCloseDay: Int

    public init(chargeDay: Int, statementCloseDay: Int) {
        self.chargeDay = min(max(chargeDay, 1), 28)
        self.statementCloseDay = min(max(statementCloseDay, 1), 31)
    }

    /// Date the purchase actually hits the bank account.
    public func settlementDate(forPurchaseOn purchase: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day], from: purchase)
        guard let year = comps.year, let month = comps.month, let day = comps.day else { return purchase }
        // Purchases up to the close day belong to the statement charged next month.
        let monthsAhead = day <= statementCloseDay ? 1 : 2
        var target = DateComponents()
        target.year = year
        target.month = month + monthsAhead
        target.day = chargeDay
        return calendar.date(from: target) ?? purchase
    }
}

/// Generates the schedule of an installment plan (tashlumim).
public struct InstallmentSchedule: Sendable {
    public struct Payment: Hashable, Sendable {
        public let index: Int          // 1-based
        public let dueDate: Date
        public let amount: Money
    }

    public static func payments(
        total: Money,
        count: Int,
        firstChargeDate: Date,
        calendar: Calendar
    ) throws -> [Payment] {
        let parts = try total.allocate(into: count)
        return parts.enumerated().map { offset, amount in
            let due = calendar.date(byAdding: .month, value: offset, to: firstChargeDate) ?? firstChargeDate
            return Payment(index: offset + 1, dueDate: due, amount: amount)
        }
    }
}
