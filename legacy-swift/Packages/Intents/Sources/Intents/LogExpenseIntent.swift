import AppIntents
import Foundation
import CoreModels
import Persistence

/// Quick Log: runs without opening the app (widget button, Control, Action button, Siri).
/// Writes through the shared App Group store; the main app reconciles on next launch.
public struct LogExpenseIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Expense"
    public static let openAppWhenRun = false

    @Parameter(title: "Amount") public var amount: Double     // AppIntents has no Decimal param; converted below
    @Parameter(title: "Note") public var note: String?

    public init() {}
    public init(amount: Double, note: String? = nil) {
        self.amount = amount
        self.note = note
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Round-trip through a String so the Double never touches the money math.
        let decimal = Decimal(string: String(format: "%.2f", amount)) ?? 0
        let money = Money(-decimal, .default)
        let container = try ModelContainerFactory.make(.appGroup)
        _ = try await LedgerActor(modelContainer: container).log(QuickLogDraft(amount: money, note: note))
        return .result(dialog: "Logged \(money.magnitude.amount.formatted(.currency(code: money.currency.rawValue)))")
    }
}
