import Foundation

/// Financial Stress Index inputs. All values are computed on-device and never leave it.
public struct StressInputs: Sendable, Hashable {
    /// z-score of 7-day spend vs the user's 90-day baseline at the same pay-cycle point.
    public var spendingVelocityZ: Double
    /// P(balance < buffer before next income), from Runway.
    public var runwayRisk: Double
    /// (fixed + installment obligations) / expected income.
    public var commitmentLoad: Double
    /// Rolling std-dev of daily discretionary spend / its mean (coefficient of variation).
    public var volatilityCV: Double
    /// Liquid balance / average monthly essential spend (months of buffer).
    public var bufferMonths: Double

    public init(spendingVelocityZ: Double, runwayRisk: Double, commitmentLoad: Double, volatilityCV: Double, bufferMonths: Double) {
        self.spendingVelocityZ = spendingVelocityZ; self.runwayRisk = runwayRisk; self.commitmentLoad = commitmentLoad
        self.volatilityCV = volatilityCV; self.bufferMonths = bufferMonths
    }
}

public struct StressBreakdown: Sendable, Hashable {
    public enum Band: String, Sendable { case calm, watch, elevated }
    public var score: Int                         // 0...100
    public var components: [String: Double]       // each 0...1 before weighting — drives the "why" sheet
    public var band: Band { score < 35 ? .calm : (score < 65 ? .watch : .elevated) }
}

/// Weights are the blueprint's starting values; tune with user research.
public struct StressIndexCalculator: Sendable {
    public var weights: [String: Double] = [
        "velocity": 0.30, "runway": 0.30, "commitments": 0.20, "volatility": 0.10, "buffer": 0.10,
    ]
    public init() {}

    public func score(_ i: StressInputs) -> StressBreakdown {
        let c: [String: Double] = [
            "velocity": clamp((i.spendingVelocityZ + 1) / 3),     // z=-1 → 0, z=2 → 1
            "runway": clamp(i.runwayRisk),
            "commitments": clamp((i.commitmentLoad - 0.3) / 0.5), // ≤30% calm, ≥80% max
            "volatility": clamp(i.volatilityCV / 1.5),
            "buffer": clamp(1 - i.bufferMonths / 3),              // 3+ months → 0 stress
        ]
        let total = c.reduce(0.0) { $0 + $1.value * (weights[$1.key] ?? 0) }
        return StressBreakdown(score: Int((total * 100).rounded()), components: c)
    }

    private func clamp(_ x: Double) -> Double { x.isNaN ? 0 : min(1, max(0, x)) }
}
