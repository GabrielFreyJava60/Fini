"""Pulse: explainable 0-100 financial stress index."""
from __future__ import annotations

import math
from dataclasses import dataclass, field

DEFAULT_WEIGHTS = {"velocity": 0.30, "runway": 0.30, "commitments": 0.20, "volatility": 0.10, "buffer": 0.10}

EXPLANATIONS = {
    "velocity": ("Темп трат за 7 дней относительно вашей нормы", "Spending pace vs your 90-day baseline"),
    "runway": ("Риск уйти ниже подушки до следующего дохода", "Risk of dropping below buffer before payday"),
    "commitments": ("Доля обязательных платежей и рассрочек в доходе", "Fixed + installment load vs income"),
    "volatility": ("Нестабильность ежедневных трат", "Day-to-day spending volatility"),
    "buffer": ("Сколько месяцев вы продержитесь на сбережениях", "Months of essential spend covered"),
}


@dataclass(frozen=True, slots=True)
class StressInputs:
    spending_velocity_z: float
    runway_risk: float
    commitment_load: float
    volatility_cv: float
    buffer_months: float


@dataclass(slots=True)
class StressBreakdown:
    score: int
    components: dict[str, float]
    weights: dict[str, float] = field(default_factory=lambda: dict(DEFAULT_WEIGHTS))

    @property
    def band(self) -> str:
        return "calm" if self.score < 35 else ("watch" if self.score < 65 else "elevated")

    def contributions(self) -> list[tuple[str, float]]:
        """(component, points out of 100), largest first — drives the 'why' screen."""
        pts = [(k, v * self.weights.get(k, 0) * 100) for k, v in self.components.items()]
        return sorted(pts, key=lambda kv: kv[1], reverse=True)


def _clamp(x: float) -> float:
    return 0.0 if math.isnan(x) else min(1.0, max(0.0, x))


class StressIndexCalculator:
    def __init__(self, weights: dict[str, float] | None = None):
        self.weights = dict(weights or DEFAULT_WEIGHTS)

    def score(self, i: StressInputs) -> StressBreakdown:
        c = {
            "velocity": _clamp((i.spending_velocity_z + 1) / 3),
            "runway": _clamp(i.runway_risk),
            "commitments": _clamp((i.commitment_load - 0.3) / 0.5),
            "volatility": _clamp(i.volatility_cv / 1.5),
            "buffer": _clamp(1 - i.buffer_months / 3),
        }
        total = sum(v * self.weights.get(k, 0) for k, v in c.items())
        return StressBreakdown(int(total * 100 + 0.5), c, dict(self.weights))
