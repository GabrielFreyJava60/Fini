import Foundation
import CoreModels

/// Deterministic, seedable PRNG (SplitMix64) so simulations are reproducible in tests.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A known future cash movement (salary, rent, card charge, installment payment).
public struct ScheduledFlow: Sendable, Hashable {
    public var dayOffset: Int          // 0 = today
    public var amountMinor: Int64      // signed
    public var label: String
    public init(dayOffset: Int, amountMinor: Int64, label: String) {
        self.dayOffset = dayOffset; self.amountMinor = amountMinor; self.label = label
    }
}

/// Empirical daily variable spend for one category (positive minor units), with weekday multipliers.
public struct VariableSpendModel: Sendable {
    public var samples: [Int64]                  // observed daily spends, incl. zero days
    public var weekdayMultiplier: [Double]       // 7 entries, index 0 = Sunday
    public init(samples: [Int64], weekdayMultiplier: [Double] = Array(repeating: 1, count: 7)) {
        self.samples = samples; self.weekdayMultiplier = weekdayMultiplier
    }
}

public struct RunwayInput: Sendable {
    public var startingBalanceMinor: Int64
    public var currency: CurrencyCode
    public var horizonDays: Int
    public var startWeekday: Int                 // 0 = Sunday
    public var scheduled: [ScheduledFlow]
    public var variable: [VariableSpendModel]
    public var safetyBufferMinor: Int64
    public init(startingBalanceMinor: Int64, currency: CurrencyCode = .default, horizonDays: Int, startWeekday: Int,
                scheduled: [ScheduledFlow], variable: [VariableSpendModel], safetyBufferMinor: Int64 = 0) {
        self.startingBalanceMinor = startingBalanceMinor; self.currency = currency; self.horizonDays = horizonDays
        self.startWeekday = startWeekday; self.scheduled = scheduled; self.variable = variable
        self.safetyBufferMinor = safetyBufferMinor
    }
}

public struct RunwayResult: Sendable {
    public var p10: [Int64]
    public var p50: [Int64]
    public var p90: [Int64]
    /// Share of paths that dip below zero at any point within the horizon.
    public var probabilityBelowZero: Double
    public var probabilityBelowBuffer: Double
}

/// Monte Carlo over the user's own empirical spend. The LLM never produces numbers; only this does.
public struct RunwaySimulator: Sendable {
    public var paths: Int
    public init(paths: Int = 2_000) { self.paths = paths }

    public func run(_ input: RunwayInput, seed: UInt64) -> RunwayResult {
        let days = max(1, input.horizonDays)
        var rng = SplitMix64(seed: seed)
        var scheduledByDay = [Int64](repeating: 0, count: days)
        for flow in input.scheduled where flow.dayOffset >= 0 && flow.dayOffset < days {
            scheduledByDay[flow.dayOffset] += flow.amountMinor
        }
        // balances[day][path]
        var balances = [[Int64]](repeating: [Int64](repeating: 0, count: paths), count: days)
        var belowZero = 0, belowBuffer = 0
        for p in 0..<paths {
            var balance = input.startingBalanceMinor
            var hitZero = false, hitBuffer = false
            for d in 0..<days {
                balance += scheduledByDay[d]
                let weekday = (input.startWeekday + d) % 7
                for model in input.variable where !model.samples.isEmpty {
                    let draw = model.samples[Int(rng.next() % UInt64(model.samples.count))]
                    let mult = model.weekdayMultiplier.indices.contains(weekday) ? model.weekdayMultiplier[weekday] : 1
                    balance -= Int64((Double(draw) * mult).rounded())
                }
                if balance < 0 { hitZero = true }
                if balance < input.safetyBufferMinor { hitBuffer = true }
                balances[d][p] = balance
            }
            if hitZero { belowZero += 1 }
            if hitBuffer { belowBuffer += 1 }
        }
        var p10 = [Int64](), p50 = [Int64](), p90 = [Int64]()
        p10.reserveCapacity(days); p50.reserveCapacity(days); p90.reserveCapacity(days)
        for d in 0..<days {
            let sorted = balances[d].sorted()
            p10.append(Self.percentile(sorted, 0.10))
            p50.append(Self.percentile(sorted, 0.50))
            p90.append(Self.percentile(sorted, 0.90))
        }
        return RunwayResult(p10: p10, p50: p50, p90: p90,
                            probabilityBelowZero: Double(belowZero) / Double(paths),
                            probabilityBelowBuffer: Double(belowBuffer) / Double(paths))
    }

    static func percentile(_ sorted: [Int64], _ q: Double) -> Int64 {
        guard !sorted.isEmpty else { return 0 }
        let idx = Int((Double(sorted.count - 1) * q).rounded())
        return sorted[idx]
    }
}

/// Runs off the main actor; debounced by the caller after each ledger write.
public actor SimulationActor {
    private let simulator: RunwaySimulator
    public init(simulator: RunwaySimulator = RunwaySimulator()) { self.simulator = simulator }
    public func simulate(_ input: RunwayInput, seed: UInt64 = 42) -> RunwayResult {
        simulator.run(input, seed: seed)
    }
}
