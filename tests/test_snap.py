from datetime import date
from types import SimpleNamespace as NS

from finance.core.money import Money
from finance.core.receipts import HeuristicReceiptParser, ReceiptMatcher

TEXT = 'שופרסל דיל\n12/10/2026\nחלב 6.90\nלחם 12.50\nסה"כ לתשלום 1,219.40\n3 תשלומים'


def test_hebrew_total():
    d = HeuristicReceiptParser().extract(TEXT)
    assert d.total.value == Money("1219.40") and d.installment_count == 3
    assert d.date.value == date(2026, 10, 12) and d.merchant.value == "שופרסל דיל"
    assert [n for n, _ in d.line_items] == ["חלב", "לחם"]


def test_no_total_returns_none():
    assert HeuristicReceiptParser().extract("hello\nworld") is None


def test_matcher_tolerance():
    today = date.today()
    m = ReceiptMatcher()
    assert m.matches(Money("100.90"), today, Money(-100), today)
    assert not m.matches(Money(105), today, Money(-100), today)
    assert not m.matches(Money(100), today, Money(-100, "USD"), today)


def test_best_match_prefers_merchant():
    d = HeuristicReceiptParser().extract(TEXT)
    a = NS(amount=Money("-1219.40"), date=date(2026, 10, 12), payee="Paz")
    b = NS(amount=Money("-1219.40"), date=date(2026, 10, 13), payee="שופרסל")
    assert ReceiptMatcher().best_match(d, [a, b]) is b
