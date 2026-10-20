"""Israeli card settlement (charge day / statement close) and tashlumim schedules."""
from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import date

from .money import Money


def add_months(d: date, months: int, day: int | None = None) -> date:
    m0 = d.month - 1 + months
    y, m = d.year + m0 // 12, m0 % 12 + 1
    target = d.day if day is None else day
    return date(y, m, min(target, calendar.monthrange(y, m)[1]))


@dataclass(frozen=True, slots=True)
class CardSettlementRule:
    charge_day: int          # 1..28, day the bank account is debited
    statement_close_day: int  # 1..31, purchases up to this day go on next month's charge

    def __post_init__(self):
        object.__setattr__(self, "charge_day", min(max(self.charge_day, 1), 28))
        object.__setattr__(self, "statement_close_day", min(max(self.statement_close_day, 1), 31))

    def settlement_date(self, purchase: date) -> date:
        ahead = 1 if purchase.day <= self.statement_close_day else 2
        return add_months(purchase.replace(day=1), ahead, self.charge_day)


@dataclass(frozen=True, slots=True)
class InstallmentPayment:
    index: int  # 1-based
    due_date: date
    amount: Money


def installment_schedule(total: Money, count: int, first_charge: date) -> list[InstallmentPayment]:
    parts = total.allocate(count)
    return [InstallmentPayment(i + 1, add_months(first_charge, i, first_charge.day), p) for i, p in enumerate(parts)]
