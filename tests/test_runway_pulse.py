from finance.core.pulse import StressIndexCalculator, StressInputs
from finance.core.runway import RunwayInput, RunwaySimulator, ScheduledFlow, VariableSpendModel


def test_deterministic_with_seed():
    inp = RunwayInput(500_000, 30, 2, [ScheduledFlow(10, 1_200_000, "Salary"), ScheduledFlow(2, -620_000, "Isracard")],
                      [VariableSpendModel([0, 4_500, 12_000, 30_000])])
    sim = RunwaySimulator(500)
    a, b = sim.run(inp, 7), sim.run(inp, 7)
    assert a.p50 == b.p50
    assert all(x <= y for x, y in zip(a.p10, a.p90))
    assert a.probability_below_zero > 0


def test_no_variable_spend_is_exact():
    r = RunwaySimulator(10).run(RunwayInput(100, 3, 0, [ScheduledFlow(1, -50, "x")], []), 1)
    assert r.p50 == [100, 50, 50] and r.probability_below_zero == 0


def test_calm_user():
    s = StressIndexCalculator().score(StressInputs(-1, 0, 0.2, 0, 6))
    assert s.score == 0 and s.band == "calm"


def test_stressed_user():
    s = StressIndexCalculator().score(StressInputs(3, 0.9, 0.9, 2, 0))
    assert s.score >= 90 and s.band == "elevated"
    assert s.contributions()[0][0] in ("velocity", "runway")


def test_weights_sum_to_one():
    assert abs(sum(StressIndexCalculator().weights.values()) - 1) < 1e-9
