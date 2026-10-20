import SwiftUI
import CoreModels

/// Semantic tokens. Colors resolve from the asset catalog (light/dark/high-contrast variants).
public enum DSColor {
    public static let moneyIn = Color("money.in", bundle: .module)
    public static let moneyOut = Color("money.out", bundle: .module)        // neutral ink, never red
    public static let riskCalm = Color("risk.calm", bundle: .module)
    public static let riskWatch = Color("risk.watch", bundle: .module)
    public static let riskElevated = Color("risk.elevated", bundle: .module)
    public static func category(_ token: String) -> Color { Color(token, bundle: .module) }
}

public enum DSFont {
    public static let hero = Font.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit()
    public static let amount = Font.system(.title3, design: .rounded, weight: .medium).monospacedDigit()
}

/// Formats Money with locale; LTR-isolated so numbers render correctly inside Hebrew text.
public struct MoneyText: View {
    let money: Money
    public init(_ money: Money) { self.money = money }
    public var body: some View {
        Text(money.amount, format: .currency(code: money.currency.rawValue))
            .font(DSFont.amount)
            .contentTransition(.numericText(value: NSDecimalNumber(decimal: money.amount).doubleValue))
            .environment(\.layoutDirection, .leftToRight)
            .privacySensitive()
    }
}
