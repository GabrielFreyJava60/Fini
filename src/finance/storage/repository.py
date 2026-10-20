"""Repository: all writes go through here → soft delete + event log + HLC stamps."""
from __future__ import annotations

import json
import uuid
from dataclasses import asdict, dataclass
from datetime import date, datetime, timezone

from ..core.cards import CardSettlementRule, installment_schedule
from ..core.categories import SEED_CATEGORIES
from ..core.money import DEFAULT_CURRENCY, Money
from .db import Database
from .hlc import HybridLogicalClock

TXN_FIELDS = ("id", "account_id", "category_id", "date", "settlement_date", "amount_minor", "currency", "kind",
              "source", "payee", "note", "installment_plan_id", "installment_index", "created_at",
              "updated_hlc", "is_deleted")


@dataclass(slots=True)
class Transaction:
    id: str
    date: date
    amount: Money
    kind: str
    category_id: str | None = None
    account_id: str | None = None
    settlement_date: date | None = None
    payee: str | None = None
    note: str | None = None
    source: str = "manual"

    @property
    def cash_flow_date(self) -> date:
        return self.settlement_date or self.date


@dataclass(slots=True)
class Conflict:
    entity: str
    entity_id: str
    field: str
    local: object
    remote: object
    winner: str


def _d(s):
    return date.fromisoformat(s) if s else None


class LedgerRepository:
    def __init__(self, db: Database, node_id: str | None = None, clock: HybridLogicalClock | None = None):
        self.db = db
        self.c = db.conn
        self.node_id = node_id or self._setting("node_id") or uuid.uuid4().hex[:8]
        self._set_setting("node_id", self.node_id)
        self.clock = clock or HybridLogicalClock(self.node_id)

    # settings
    def _setting(self, key):
        r = self.c.execute("SELECT value FROM setting WHERE key=?", (key,)).fetchone()
        return r[0] if r else None

    def _set_setting(self, key, value):
        self.c.execute("INSERT INTO setting(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                       (key, str(value)))

    get_setting, set_setting = _setting, _set_setting

    def _log(self, entity, entity_id, op, hlc, payload):
        self.c.execute("INSERT INTO event_log(entity,entity_id,op,hlc,payload) VALUES(?,?,?,?,?)",
                       (entity, entity_id, op, hlc, json.dumps(payload, ensure_ascii=False, default=str)))

    # seeding
    def seed_categories(self) -> int:
        """Idempotent; safe on every launch and on two devices (stable UUIDv5 ids)."""
        added = 0
        self.c.execute("BEGIN")
        try:
            for order, s in enumerate(SEED_CATEGORIES):
                hlc = self.clock.tick()
                cur = self.c.execute(
                    "INSERT OR IGNORE INTO category(id,system_key,name_he,name_en,name_ru,kind,essential,icon,sort_order,updated_hlc)"
                    " VALUES(?,?,?,?,?,?,?,?,?,?)",
                    (s.id, s.system_key, s.name_he, s.name_en, s.name_ru, s.kind, int(s.essential), s.icon, order, hlc))
                if cur.rowcount:
                    added += 1
                    self._log("category", s.id, "insert", hlc, {"system_key": s.system_key})
            self.c.execute("COMMIT")
        except Exception:
            self.c.execute("ROLLBACK")
            raise
        return added

    def categories(self, kind: str | None = None):
        q = "SELECT * FROM category WHERE is_deleted=0" + (" AND kind=?" if kind else "") + " ORDER BY sort_order"
        return [dict(r) for r in self.c.execute(q, (kind,) if kind else ())]

    # accounts
    def add_account(self, name, kind="checking", currency=DEFAULT_CURRENCY, opening_minor=0,
                    charge_day=None, statement_close_day=None) -> str:
        aid, hlc = str(uuid.uuid4()), self.clock.tick()
        self.c.execute("INSERT INTO account(id,name,kind,currency,opening_balance_minor,charge_day,statement_close_day,updated_hlc)"
                       " VALUES(?,?,?,?,?,?,?,?)", (aid, name, kind, currency, opening_minor, charge_day, statement_close_day, hlc))
        self._log("account", aid, "insert", hlc, {"name": name, "kind": kind})
        return aid

    def account(self, aid):
        r = self.c.execute("SELECT * FROM account WHERE id=?", (aid,)).fetchone()
        return dict(r) if r else None

    # transactions
    def add_transaction(self, amount: Money, kind: str = "expense", on: date | None = None, category_id=None,
                        account_id=None, payee=None, note=None, source="manual",
                        _plan=None, _index=None, _settlement=None) -> str:
        on = on or date.today()
        if kind == "expense" and amount.amount > 0:
            amount = -amount  # expenses stored negative
        settlement = _settlement
        if settlement is None and account_id:
            acc = self.account(account_id)
            if acc and acc["charge_day"]:
                settlement = CardSettlementRule(acc["charge_day"], acc["statement_close_day"] or 31).settlement_date(on)
        tid, hlc = str(uuid.uuid4()), self.clock.tick()
        row = dict(id=tid, account_id=account_id, category_id=category_id, date=on.isoformat(),
                   settlement_date=settlement.isoformat() if settlement else None, amount_minor=amount.minor_units,
                   currency=amount.currency, kind=kind, source=source, payee=payee, note=note,
                   installment_plan_id=_plan, installment_index=_index,
                   created_at=datetime.now(timezone.utc).isoformat(), updated_hlc=hlc, is_deleted=0)
        self.c.execute(f"INSERT INTO txn({','.join(row)}) VALUES({','.join('?' * len(row))})", tuple(row.values()))
        self._log("txn", tid, "insert", hlc, row)
        return tid

    def add_installment_purchase(self, total: Money, count: int, purchase_date: date, account_id: str, **kw) -> list[str]:
        acc = self.account(account_id)
        if not acc or not acc["charge_day"]:
            raise ValueError("installments require a card account with a charge day")
        first = CardSettlementRule(acc["charge_day"], acc["statement_close_day"] or 31).settlement_date(purchase_date)
        plan = str(uuid.uuid4())
        ids = []
        self.c.execute("BEGIN")
        try:
            for p in installment_schedule(abs(total), count, first):
                ids.append(self.add_transaction(p.amount, "expense", purchase_date, account_id=account_id,
                                                _plan=plan, _index=p.index, _settlement=p.due_date, **kw))
            self.c.execute("COMMIT")
        except Exception:
            self.c.execute("ROLLBACK")
            raise
        return ids

    def update_transaction(self, tid: str, **changes) -> None:
        allowed = {"category_id", "payee", "note", "date", "amount_minor", "kind", "settlement_date"}
        bad = set(changes) - allowed
        if bad:
            raise ValueError(f"cannot update {bad}")
        if not self.c.execute("SELECT 1 FROM txn WHERE id=? AND is_deleted=0", (tid,)).fetchone():
            raise KeyError(tid)
        hlc = self.clock.tick()
        changes = {k: (v.isoformat() if isinstance(v, date) else v) for k, v in changes.items()}
        sets = ",".join(f"{k}=?" for k in changes)
        self.c.execute(f"UPDATE txn SET {sets}, updated_hlc=? WHERE id=?", (*changes.values(), hlc, tid))
        self._log("txn", tid, "update", hlc, changes)

    def delete_transaction(self, tid: str) -> None:
        hlc = self.clock.tick()
        cur = self.c.execute("UPDATE txn SET is_deleted=1, updated_hlc=? WHERE id=? AND is_deleted=0", (hlc, tid))
        if not cur.rowcount:
            raise KeyError(tid)
        self._log("txn", tid, "delete", hlc, {})

    def restore_transaction(self, tid: str) -> None:
        hlc = self.clock.tick()
        self.c.execute("UPDATE txn SET is_deleted=0, updated_hlc=? WHERE id=?", (hlc, tid))
        self._log("txn", tid, "restore", hlc, {})

    def undo_last(self) -> bool:
        """Undo the newest local insert/delete using the event log."""
        r = self.c.execute("SELECT * FROM event_log WHERE entity='txn' AND op IN ('insert','delete') "
                           "AND hlc LIKE ? ORDER BY seq DESC LIMIT 1", (f"%-{self.node_id}",)).fetchone()
        if not r:
            return False
        (self.delete_transaction if r["op"] == "insert" else self.restore_transaction)(r["entity_id"])
        return True

    def _row_to_tx(self, r) -> Transaction:
        return Transaction(r["id"], _d(r["date"]), Money.from_minor(r["amount_minor"], r["currency"]), r["kind"],
                           r["category_id"], r["account_id"], _d(r["settlement_date"]), r["payee"], r["note"], r["source"])

    def transactions(self, start: date | None = None, end: date | None = None, include_deleted=False, limit=None):
        q, a = "SELECT * FROM txn WHERE 1=1", []
        if not include_deleted:
            q += " AND is_deleted=0"
        if start:
            q += " AND date>=?"; a.append(start.isoformat())
        if end:
            q += " AND date<?"; a.append(end.isoformat())
        q += " ORDER BY date DESC, created_at DESC" + (f" LIMIT {int(limit)}" if limit else "")
        return [self._row_to_tx(r) for r in self.c.execute(q, a)]

    def balance(self, currency=DEFAULT_CURRENCY) -> Money:
        opening = self.c.execute("SELECT COALESCE(SUM(opening_balance_minor),0) FROM account WHERE is_deleted=0 AND currency=? "
                                 "AND charge_day IS NULL", (currency,)).fetchone()[0]
        moved = self.c.execute("SELECT COALESCE(SUM(amount_minor),0) FROM txn WHERE is_deleted=0 AND currency=? "
                               "AND COALESCE(settlement_date,date)<=?", (currency, date.today().isoformat())).fetchone()[0]
        return Money.from_minor(opening + moved, currency)

    # budgets
    def set_budget(self, category_id: str, month: str, limit: Money) -> None:
        hlc = self.clock.tick()
        self.c.execute("INSERT INTO budget(id,category_id,month,limit_minor,currency,updated_hlc) VALUES(?,?,?,?,?,?) "
                       "ON CONFLICT(category_id,month) DO UPDATE SET limit_minor=excluded.limit_minor, updated_hlc=excluded.updated_hlc, is_deleted=0",
                       (str(uuid.uuid4()), category_id, month, limit.minor_units, limit.currency, hlc))
        self._log("budget", f"{category_id}:{month}", "upsert", hlc, {"limit_minor": limit.minor_units})

    def budget_status(self, month: str):
        """[(category row, limit Money, spent Money)] for 'YYYY-MM'."""
        out = []
        for r in self.c.execute("SELECT b.*, c.name_he, c.name_en, c.name_ru, c.icon FROM budget b JOIN category c ON c.id=b.category_id "
                                "WHERE b.is_deleted=0 AND b.month=? ORDER BY c.sort_order", (month,)):
            spent = self.c.execute("SELECT COALESCE(-SUM(amount_minor),0) FROM txn WHERE is_deleted=0 AND category_id=? "
                                   "AND currency=? AND substr(date,1,7)=?", (r["category_id"], r["currency"], month)).fetchone()[0]
            out.append((dict(r), Money.from_minor(r["limit_minor"], r["currency"]), Money.from_minor(spent, r["currency"])))
        return out

    # sync / conflicts
    def pending_events(self):
        return [dict(r) for r in self.c.execute("SELECT * FROM event_log WHERE synced=0 ORDER BY seq")]

    def mark_synced(self, up_to_seq: int):
        self.c.execute("UPDATE event_log SET synced=1 WHERE seq<=?", (up_to_seq,))

    def apply_remote_txn(self, remote: dict) -> list[Conflict]:
        """Merge a remote txn row. Field-level LWW by HLC; deletes win ties (tombstone-wins) so
        a delete on one device isn't resurrected by a concurrent edit with an older clock."""
        self.clock.receive(remote["updated_hlc"])
        local = self.c.execute("SELECT * FROM txn WHERE id=?", (remote["id"],)).fetchone()
        if local is None:
            row = {k: remote.get(k) for k in TXN_FIELDS}
            self.c.execute(f"INSERT INTO txn({','.join(TXN_FIELDS)}) VALUES({','.join('?' * len(TXN_FIELDS))})", tuple(row.values()))
            self._log("txn", remote["id"], "merge", remote["updated_hlc"], {"inserted": True})
            return []
        local = dict(local)
        remote_wins = remote["updated_hlc"] > local["updated_hlc"]
        conflicts, merged = [], dict(local)
        for f in TXN_FIELDS:
            if f in ("id", "updated_hlc", "created_at") or f not in remote:
                continue
            if remote[f] != local[f]:
                winner = "remote" if remote_wins else "local"
                conflicts.append(Conflict("txn", local["id"], f, local[f], remote[f], winner))
                if remote_wins:
                    merged[f] = remote[f]
        if remote.get("is_deleted") and remote["updated_hlc"] == local["updated_hlc"]:
            merged["is_deleted"] = 1
        merged["updated_hlc"] = max(remote["updated_hlc"], local["updated_hlc"])
        cols = [f for f in TXN_FIELDS if f != "id"]
        self.c.execute(f"UPDATE txn SET {','.join(f + '=?' for f in cols)} WHERE id=?",
                       (*[merged[f] for f in cols], local["id"]))
        if conflicts:
            self._log("txn", local["id"], "merge", merged["updated_hlc"], {"conflicts": [asdict(x) for x in conflicts]})
        return conflicts

    def raw_txn(self, tid):
        r = self.c.execute("SELECT * FROM txn WHERE id=?", (tid,)).fetchone()
        return dict(r) if r else None
