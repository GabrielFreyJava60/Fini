from datetime import date, timedelta

import pytest

from finance.assistant import Assistant
from finance.core.money import Money
from finance.storage import Database, LedgerRepository
from finance.ui.formatting import parse_amount, sparkline


@pytest.fixture
def repo():
    r = LedgerRepository(Database(), node_id="A")
    r.seed_categories()
    r.add_account("Leumi", opening_minor=500_000)
    today = date.today()
    for i in range(1, 40):
        r.add_transaction(Money(60 + i % 5 * 20), on=today - timedelta(days=i))
    r.add_transaction(Money(12000), "income", on=today - timedelta(days=5), payee="Salary")
    return r


def test_runway_answer_ru(repo):
    a = Assistant(repo).ask("Хватит до зарплаты?")
    assert a.intent == "runway" and "ожидаемый баланс" in a.text and "₪" in a.text


def test_afford(repo):
    a = Assistant(repo).ask("Могу потратить 500?")
    assert a.intent == "runway" and "₪500.00" in a.text


def test_pulse_explains(repo):
    a = Assistant(repo).ask("Почему у меня такой стресс?")
    assert a.intent == "pulse" and "/100" in a.text


def test_spend_week(repo):
    a = Assistant(repo).ask("Сколько я потратил за неделю?")
    assert a.intent == "spend" and "7 дн." in a.text


def test_hebrew_receipt(repo):
    a = Assistant(repo).ask('שופרסל\nחלב 6.90\nסה"כ 300.01\n3 תשלומים')
    assert a.intent == "receipt" and "₪300.01" in a.text and "₪100.01" in a.text


def test_help_and_hebrew(repo):
    assert Assistant(repo).ask("привет").intent == "help"
    assert Assistant(repo).ask("מה התחזית?").intent == "runway"


def test_parse_amount():
    assert str(parse_amount("1 234,50")) == "1234.50" and str(parse_amount("₪12")) == "12"
    with pytest.raises(ValueError):
        parse_amount("abc")
    with pytest.raises(ValueError):
        parse_amount("-5")
    assert len(sparkline(list(range(100)))) <= 34
