"""Runway: seeded Monte Carlo over the user's own empirical daily spend (stdlib random)."""
from __future__ import annotations

import random
from dataclasses import dataclass, field

from .money import DEFAULT_CURRENCY


@dataclass(frozen=True, slots=True)
class ScheduledFlow:
    day_offset: int   # 0 = today
    amount_minor: int  # signed
    label: str


@dataclass(slots=True)
class VariableSpendModel:
    samples: list[int]  # observed daily spends (positive minor units), incl. zero days
    weekday_multiplier: list[float] = field(default_factory=lambda: [1.0] * 7)  # index 0 = Sunday


@dataclass(slots=True)
class RunwayInput:
    starting_balance_minor: int
    horizon_days: int
    start_weekday: int  # 0 = Sunday
    scheduled: list[ScheduledFlow]
    variable: list[VariableSpendModel]
    safety_buffer_minor: int = 0
    currency: str = DEFAULT_CURRENCY


@dataclass(slots=True)
class RunwayResult:
    p10: list[int]
    p50: list[int]
    p90: list[int]
    probability_below_zero: float
    probability_below_buffer: float
    currency: str = DEFAULT_CURRENCY

    def first_risky_day(self) -> int | None:
        return next((d for d, v in enumerate(self.p10) if v < 0), None)


def _percentile(sorted_vals: list[int], q: float) -> int:
    if not sorted_vals:
        return 0
    # Match Swift's .rounded() (half away from zero) on a non-negative index.
    idx = int((len(sorted_vals) - 1) * q + 0.5)
    return sorted_vals[idx]


def _round_half_away(x: float) -> int:
    return int(x + 0.5) if x >= 0 else -int(-x + 0.5)


class RunwaySimulator:
    def __init__(self, paths: int = 2000):
        if paths <= 0:
            raise ValueError("paths must be positive")
        self.paths = paths

    def run(self, inp: RunwayInput, seed: int = 42) -> RunwayResult:
        days = max(1, inp.horizon_days)
        rng = random.Random(seed)
        by_day = [0] * days
        for f in inp.scheduled:
            if 0 <= f.day_offset < days:
                by_day[f.day_offset] += f.amount_minor
        models = [m for m in inp.variable if m.samples]
        balances = [[0] * self.paths for _ in range(days)]
        below_zero = below_buffer = 0
        for p in range(self.paths):
            bal = inp.starting_balance_minor
            hit0 = hitb = False
            for d in range(days):
                bal += by_day[d]
                wd = (inp.start_weekday + d) % 7
                for m in models:
                    draw = m.samples[rng.randrange(len(m.samples))]
                    mult = m.weekday_multiplier[wd] if wd < len(m.weekday_multiplier) else 1.0
                    bal -= _round_half_away(draw * mult)
                hit0 |= bal < 0
                hitb |= bal < inp.safety_buffer_minor
                balances[d][p] = bal
            below_zero += hit0
            below_buffer += hitb
        p10, p50, p90 = [], [], []
        for d in range(days):
            s = sorted(balances[d])
            p10.append(_percentile(s, 0.10)); p50.append(_percentile(s, 0.50)); p90.append(_percentile(s, 0.90))
        return RunwayResult(p10, p50, p90, below_zero / self.paths, below_buffer / self.paths, inp.currency)
