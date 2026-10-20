"""Builds the full Toga app on the dummy backend (no GUI) and drives quick-add."""
import os

import pytest

toga = pytest.importorskip("toga")


@pytest.fixture
def app(monkeypatch, tmp_path):
    monkeypatch.setenv("TOGA_BACKEND", "toga_dummy")
    monkeypatch.setenv("HOME", str(tmp_path))
    import finance.security.keychain as kc
    monkeypatch.setattr(kc, "_instance", None)  # fresh in-memory keychain per test
    from finance.app import FinanceApp
    a = FinanceApp("Финансы", "com.gabrielfreidlin.finance")
    return a


def test_quick_add_flow(app):
    qa = app.views[1]
    qa.amount.value = "45,90"
    qa.category.value = qa.category.items[0]
    qa.save(None)
    assert "✓" in qa.status.text
    assert app.repo.transactions()[0].amount.minor_units == -4590
    assert len(app.views[0].table.data) == 1


def test_phrase_shown_once(app):
    first = app.vault_phrase_once()
    assert len(first.split()) == 24
    assert "уже была показана" in app.vault_phrase_once()


def test_insights_and_export(app):
    app.views[3].q.value = "Хватит до зарплаты?"
    app.views[3].ask(None)
    assert "баланс" in app.views[3].a.value
    s = app.views[4]
    s.passphrase.value = "longpassword"
    s.export(None)
    assert "Сохранено" in s.info.value
