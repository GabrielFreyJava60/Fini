from datetime import date, timedelta

import pytest

from finance.core.categories import SEED_CATEGORIES
from finance.core.money import Money
from finance.storage import Database, LedgerRepository
from finance.storage.db import SCHEMA_VERSION
from finance.storage.hlc import HybridLogicalClock, parse


@pytest.fixture
def repo():
    return LedgerRepository(Database(), node_id="A")


def test_migrations(tmp_path):
    db = Database(tmp_path / "x.db")
    assert db.version == SCHEMA_VERSION
    db.close()
    assert Database(tmp_path / "x.db").version == SCHEMA_VERSION  # idempotent reopen


def test_seed_idempotent_stable_ids(repo):
    assert repo.seed_categories() == len(SEED_CATEGORIES)
    assert repo.seed_categories() == 0
    other = LedgerRepository(Database(), node_id="B"); other.seed_categories()
    assert {c["id"] for c in repo.categories()} == {c["id"] for c in other.categories()}
    assert all(c["name_he"] and c["name_en"] for c in repo.categories())


def test_soft_delete_and_undo(repo):
    tid = repo.add_transaction(Money(50), payee="Aroma")
    assert repo.transactions()[0].amount == Money(-50)
    repo.delete_transaction(tid)
    assert repo.transactions() == [] and repo.raw_txn(tid)["is_deleted"] == 1
    assert repo.undo_last()  # undoes delete
    assert len(repo.transactions()) == 1
    ops = [e["op"] for e in repo.pending_events()]
    assert ops[-3:] == ["insert", "delete", "restore"]


def test_card_settlement_and_installments(repo):
    card = repo.add_account("Isracard", "credit_card", charge_day=10, statement_close_day=31)
    ids = repo.add_installment_purchase(Money(4000), 3, date(2026, 10, 20), card)
    rows = [repo.raw_txn(i) for i in ids]
    assert [r["amount_minor"] for r in rows] == [-133_334, -133_333, -133_333]
    assert [r["settlement_date"] for r in rows] == ["2026-11-10", "2026-12-10", "2027-01-10"]


def test_budget_status(repo):
    repo.seed_categories()
    cat = repo.categories("expense")[0]["id"]
    month = date.today().strftime("%Y-%m")
    repo.set_budget(cat, month, Money(1000))
    repo.add_transaction(Money(250), category_id=cat)
    (_, limit, spent), = repo.budget_status(month)
    assert limit == Money(1000) and spent == Money(250)


def test_lww_conflict_remote_newer(repo):
    tid = repo.add_transaction(Money(10), payee="local")
    remote = dict(repo.raw_txn(tid), payee="remote", updated_hlc="9999999999999-0000-B")
    conflicts = repo.apply_remote_txn(remote)
    assert conflicts[0].field == "payee" and conflicts[0].winner == "remote"
    assert repo.raw_txn(tid)["payee"] == "remote"


def test_lww_conflict_local_newer(repo):
    tid = repo.add_transaction(Money(10), payee="local")
    remote = dict(repo.raw_txn(tid), payee="old", updated_hlc="0000000000001-0000-B")
    repo.apply_remote_txn(remote)
    assert repo.raw_txn(tid)["payee"] == "local"


def test_remote_insert(repo):
    src = LedgerRepository(Database(), node_id="B")
    tid = src.add_transaction(Money(7))
    assert repo.apply_remote_txn(src.raw_txn(tid)) == []
    assert repo.transactions()[0].id == tid


def test_hlc_monotonic():
    c = HybridLogicalClock("A", now=lambda: 1000)
    a, b = c.tick(), c.tick()
    assert a < b and parse(b) == (1000, 1, "A")
    merged = c.receive("0000000005000-0003-B")
    assert merged > "0000000005000-0003-B"
