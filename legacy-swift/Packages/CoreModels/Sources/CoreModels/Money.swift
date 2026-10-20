import Foundation

public enum MoneyError: Error, Equatable, Sendable {
    case currencyMismatch(CurrencyCode, CurrencyCode)
    case invalidAllocationCount(Int)
}

/// Exact money value. `Decimal` for arithmetic, `Int64` minor units for storage and sums.
/// Never use `Double` for money.
public struct Money: Hashable, Codable, Sendable, CustomStringConvertible {
    public var amount: Decimal
    public var currency: CurrencyCode

    public init(_ amount: Decimal, _ currency: CurrencyCode = .default) {
        self.amount = amount
        self.currency = currency
    }

    public init(minorUnits: Int64, currency: CurrencyCode = .default) {
        self.amount = Decimal(minorUnits) / Money.scale(for: currency)
        self.currency = currency
    }

    public static func zero(_ currency: CurrencyCode = .default) -> Money { Money(0, currency) }

    /// Rounded (banker's) to the currency's minor unit.
    public var minorUnits: Int64 {
        var scaled = amount * Money.scale(for: currency)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .bankers)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    public var isNegative: Bool { amount < 0 }
    public var negated: Money { Money(-amount, currency) }
    public var magnitude: Money { Money(amount < 0 ? -amount : amount, currency) }

    public func adding(_ other: Money) throws -> Money {
        guard other.currency == currency else { throw MoneyError.currencyMismatch(currency, other.currency) }
        return Money(amount + other.amount, currency)
    }

    public func subtracting(_ other: Money) throws -> Money {
        try adding(other.negated)
    }

    public func multiplied(by factor: Decimal) -> Money {
        Money(amount * factor, currency)
    }

    /// Converts with an explicit rate (1 unit of `self.currency` = `rate` units of `target`).
    public func converted(to target: CurrencyCode, rate: Decimal) -> Money {
        Money(amount * rate, target)
    }

    /// Splits into `count` parts that sum exactly to the original (in minor units).
    /// The remainder agorot go to the FIRST parts, matching how Israeli issuers
    /// typically bill tashlumim (first payment absorbs the rounding).
    public func allocate(into count: Int) throws -> [Money] {
        guard count > 0 else { throw MoneyError.invalidAllocationCount(count) }
        let total = minorUnits
        let base = total / Int64(count)
        let remainder = total - base * Int64(count) // same sign as total
        let step: Int64 = remainder >= 0 ? 1 : -1
        var left = remainder
        return (0..<count).map { _ in
            var part = base
            if left != 0 { part += step; left -= step }
            return Money(minorUnits: part, currency: currency)
        }
    }

    public var description: String { "\(amount) \(currency.rawValue)" }

    static func scale(for currency: CurrencyCode) -> Decimal {
        var result = Decimal(1)
        for _ in 0..<currency.minorUnitDigits { result *= 10 }
        return result
    }
}
