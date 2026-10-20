"""Builds Runway/Pulse inputs from ledger transactions (pure functions over Transaction-like objects)."""
from __future__ import annotations

import statistics
from datetime import date, timedelta

from .pulse import StressIndexCalculator, StressInputs
from .runway import RunwayInput, RunwaySimulator, ScheduledFlow, VariableSpendModel


def daily_spend(txns, today: date, days: int = 90) -> list[int]:
    start = today - timedelta(days=days)
    buckets = [0] * days
    for t in txns:
        if t.kind == "expense" and start <= t.date < today:
            buckets[(t.date - start).days] += -t.amount.minor_units
    return buckets


def build_runway_input(balance_minor: int, txns, today: date, horizon: int = 30,
                       buffer_minor: int = 0, currency: str = "ILS") -> RunwayInput:
    scheduled = [ScheduledFlow((t.cash_flow_date - today).days, t.amount.minor_units, t.payee or t.kind)
                 for t in txns if t.cash_flow_date > today and t.amount.currency == currency]
    past = [t for t in txns if t.cash_flow_date <= today and t.amount.currency == currency]
    samples = daily_spend(past, today)
    variable = [VariableSpendModel(samples)] if any(samples) else []
    return RunwayInput(balance_minor, horizon, today.isoweekday() % 7, scheduled, variable, buffer_minor, currency)


def compute(repo, today: date | None = None, horizon: int = 30, paths: int = 1000, seed: int = 42):
    """Returns (runway_result, stress_breakdown, stress_inputs)."""
    today = today or date.today()
    txns = repo.transactions()
    bal = repo.balance().minor_units
    buffer_minor = int(repo.get_setting("buffer_minor") or 0)
    inp = build_runway_input(bal, txns, today, horizon, buffer_minor)
    rr = RunwaySimulator(paths).run(inp, seed)
    daily = daily_spend([t for t in txns if t.cash_flow_date <= today], today)
    base = daily[:-7] or [0]
    mu, sd = statistics.fmean(base), (statistics.pstdev(base) or 1.0)
    week = statistics.fmean(daily[-7:]) if daily else 0
    income = sum(t.amount.minor_units for t in txns if t.kind == "income" and t.date >= today - timedelta(days=30)) or 1
    commitments = -sum(f.amount_minor for f in inp.scheduled if f.amount_minor < 0)
    mean_d = statistics.fmean(daily) if daily else 0
    cv = (statistics.pstdev(daily) / mean_d) if mean_d else 0
    monthly = mean_d * 30 or 1
    si = StressInputs((week - mu) / sd, rr.probability_below_buffer, commitments / income, cv, bal / monthly)
    return rr, StressIndexCalculator().score(si), si
