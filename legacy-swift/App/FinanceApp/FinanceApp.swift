import SwiftUI
import SwiftData
import AppIntents
import CoreModels
import Persistence
import DesignSystem
import Intents

@main
struct FinanceApp: App {
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
        }
        .modelContainer(container.modelContainer)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") { TodayPlaceholder() }
            Tab("Runway", systemImage: "chart.line.uptrend.xyaxis") { Text("Runway") }
            Tab("Ledger", systemImage: "list.bullet") { LedgerList() }
            Tab(role: .search) { Text("Search") }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

struct TodayPlaceholder: View {
    @Environment(AppContainer.self) private var container
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
            QuickAddButton {
                Task { _ = try? await container.ledger.log(QuickLogDraft(amount: Money(-14, .ils), note: "Coffee")) }
            }
            .padding(24)
        }
    }
}

struct LedgerList: View {
    @Query(filter: #Predicate<LedgerTransaction> { !$0.isTombstoned },
           sort: \LedgerTransaction.date, order: .reverse)
    private var transactions: [LedgerTransaction]

    var body: some View {
        List(transactions) { txn in
            HStack {
                Text(txn.payee ?? txn.note ?? "—")
                Spacer()
                MoneyText(txn.amount)
            }
        }
    }
}

struct FinanceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogExpenseIntent(), phrases: ["Log an expense in \(.applicationName)"],
                    shortTitle: "Log Expense", systemImageName: "plus.circle")
    }
}
