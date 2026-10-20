import Foundation

/// ISO 4217 currency code. ILS is the product default.
public struct CurrencyCode: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.uppercased()
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public static let ils: CurrencyCode = "ILS"
    public static let usd: CurrencyCode = "USD"
    public static let eur: CurrencyCode = "EUR"
    public static let gbp: CurrencyCode = "GBP"

    /// The app-wide default. Onboarding may override it from `Locale`.
    public static let `default`: CurrencyCode = .ils

    /// Number of minor-unit digits (ISO 4217 exponent). ILS = 2 (agorot).
    public var minorUnitDigits: Int {
        switch rawValue {
        case "JPY", "KRW", "VND", "CLP", "ISK", "UGX", "XAF", "XOF": return 0
        case "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND": return 3
        default: return 2
        }
    }

    public var description: String { rawValue }

    /// Basic shape validation: three ASCII uppercase letters.
    public var isWellFormed: Bool {
        rawValue.count == 3 && rawValue.allSatisfy { $0.isASCII && $0.isUppercase }
    }
}
