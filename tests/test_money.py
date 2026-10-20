from datetime import date
from decimal import Decimal

import pytest

from finance.core.cards import CardSettlementRule, installment_schedule
from finance.core.money import CurrencyMismatch, Money, MoneyError


def test_minor_units_round_trip():
    m = Money.from_minor(12_840, "ILS")
    assert m.amount == Decimal("128.4") and m.minor_units == 12_840


def test_no_float_drift():
    assert (Money("0.1") + Money("0.2")).amount == Decimal("0.3")


def test_float_rejected():
    with pytest.raises(TypeError):
        Money(0.1)


def test_currency_mismatch():
    with pytest.raises(CurrencyMismatch):
        Money(1, "ILS") + Money(1, "USD")


def test_bankers_rounding():
    assert Money("0.125").minor_units == 12 and Money("0.135").minor_units == 14


@pytest.mark.parametrize("count", [1, 2, 3, 7, 12, 36])
def test_allocation_sums_exactly(count):
    total = Money("4000.01")
    parts = total.allocate(count)
    assert len(parts) == count and sum(p.minor_units for p in parts) == total.minor_units
    assert max(p.minor_units for p in parts) - min(p.minor_units for p in parts) <= 1


def test_negative_allocation():
    assert [p.minor_units for p in Money.from_minor(-1000).allocate(3)] == [-334, -333, -333]


def test_bad_allocation():
    with pytest.raises(MoneyError):
        Money(1).allocate(0)


def test_zero_digit_currency_and_default():
    assert Money.from_minor(500, "JPY").amount == 500
    assert Money(1, "ils").currency == "ILS" and Money(1).currency == "ILS"


def test_before_close_charges_next_month():
    assert CardSettlementRule(10, 31).settlement_date(date(2026, 10, 20)) == date(2026, 11, 10)


def test_after_close_rolls_two_months():
    assert CardSettlementRule(2, 25).settlement_date(date(2026, 12, 28)) == date(2027, 2, 2)


def test_installment_schedule():
    p = installment_schedule(Money(4000), 3, date(2026, 11, 10))
    assert [x.amount.minor_units for x in p] == [133_334, 133_333, 133_333]
    assert p[-1].due_date == date(2027, 1, 10)
