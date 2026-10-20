import Testing
@testable import Pulse

@Suite struct PulseTests {
    @Test func calmUser() {
        let s = StressIndexCalculator().score(.init(spendingVelocityZ: -1, runwayRisk: 0, commitmentLoad: 0.2, volatilityCV: 0, bufferMonths: 6))
        #expect(s.score == 0)
        #expect(s.band == .calm)
    }
    @Test func stressedUser() {
        let s = StressIndexCalculator().score(.init(spendingVelocityZ: 3, runwayRisk: 0.9, commitmentLoad: 0.9, volatilityCV: 2, bufferMonths: 0))
        #expect(s.score >= 90)
        #expect(s.band == .elevated)
    }
    @Test func weightsSumToOne() {
        #expect(abs(StressIndexCalculator().weights.values.reduce(0, +) - 1) < 1e-9)
    }
}
