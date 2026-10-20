import Foundation
import Observation
import SwiftData
import Persistence
import Runway
import Pulse

/// Composition root / DI container. The only place that knows concrete implementations.
@MainActor
@Observable
final class AppContainer {
    let modelContainer: ModelContainer
    let ledger: LedgerActor
    let simulation: SimulationActor
    let stress: StressIndexCalculator

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.ledger = LedgerActor(modelContainer: modelContainer)
        self.simulation = SimulationActor()
        self.stress = StressIndexCalculator()
    }

    static func live() -> AppContainer {
        do {
            return AppContainer(modelContainer: try ModelContainerFactory.make(.appGroup))
        } catch {
            // Never silently wipe a user's ledger: surface a recovery screen instead (TODO).
            fatalError("Ledger store failed to open: \(error)")
        }
    }

    static func preview() -> AppContainer {
        AppContainer(modelContainer: try! ModelContainerFactory.make(.inMemory))
    }
}
