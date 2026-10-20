import Testing
@testable import Runway

@Suite struct RunwayTests {
    @Test func deterministicWithSeed() {
        let input = RunwayInput(startingBalanceMinor: 500_000, horizonDays: 30, startWeekday: 2,
                                scheduled: [ScheduledFlow(dayOffset: 10, amountMinor: 1_200_000, label: "Salary"),
                                            ScheduledFlow(dayOffset: 2, amountMinor: -620_000, label: "Isracard")],
                                variable: [VariableSpendModel(samples: [0, 4_500, 12_000, 30_000])])
        let sim = RunwaySimulator(paths: 500)
        let a = sim.run(input, seed: 7), b = sim.run(input, seed: 7)
        #expect(a.p50 == b.p50)
        #expect(zip(a.p10, a.p90).allSatisfy { $0 <= $1 })
        #expect(a.probabilityBelowZero > 0)       // card bill before salary should create risk
    }

    @Test func noVariableSpendIsExact() {
        let input = RunwayInput(startingBalanceMinor: 100, horizonDays: 3, startWeekday: 0,
                                scheduled: [ScheduledFlow(dayOffset: 1, amountMinor: -50, label: "x")], variable: [])
        let r = RunwaySimulator(paths: 10).run(input, seed: 1)
        #expect(r.p50 == [100, 50, 50])
        #expect(r.probabilityBelowZero == 0)
    }
}
