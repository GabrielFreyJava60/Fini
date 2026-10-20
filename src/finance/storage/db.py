"""SQLite (stdlib) with forward-only, transactional migrations tracked in PRAGMA user_version."""
from __future__ import annotations

import sqlite3
from pathlib import Path

MIGRATIONS: list[str] = [
    # v1
    """
    CREATE TABLE account (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, kind TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'ILS', opening_balance_minor INTEGER NOT NULL DEFAULT 0,
        charge_day INTEGER, statement_close_day INTEGER,
        updated_hlc TEXT NOT NULL, is_deleted INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE category (
        id TEXT PRIMARY KEY, system_key TEXT UNIQUE, name_he TEXT NOT NULL, name_en TEXT NOT NULL,
        name_ru TEXT NOT NULL DEFAULT '', kind TEXT NOT NULL, essential INTEGER NOT NULL DEFAULT 0,
        icon TEXT NOT NULL DEFAULT '', sort_order INTEGER NOT NULL DEFAULT 0,
        updated_hlc TEXT NOT NULL, is_deleted INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE txn (
        id TEXT PRIMARY KEY, account_id TEXT REFERENCES account(id),
        category_id TEXT REFERENCES category(id), date TEXT NOT NULL, settlement_date TEXT,
        amount_minor INTEGER NOT NULL, currency TEXT NOT NULL DEFAULT 'ILS',
        kind TEXT NOT NULL, source TEXT NOT NULL DEFAULT 'manual', payee TEXT, note TEXT,
        installment_plan_id TEXT, installment_index INTEGER,
        created_at TEXT NOT NULL, updated_hlc TEXT NOT NULL, is_deleted INTEGER NOT NULL DEFAULT 0);
    CREATE INDEX txn_date ON txn(is_deleted, date);
    CREATE INDEX txn_cash ON txn(is_deleted, settlement_date);
    CREATE TABLE budget (
        id TEXT PRIMARY KEY, category_id TEXT NOT NULL REFERENCES category(id), month TEXT NOT NULL,
        limit_minor INTEGER NOT NULL, currency TEXT NOT NULL DEFAULT 'ILS',
        updated_hlc TEXT NOT NULL, is_deleted INTEGER NOT NULL DEFAULT 0, UNIQUE(category_id, month));
    CREATE TABLE event_log (
        seq INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT NOT NULL, entity_id TEXT NOT NULL,
        op TEXT NOT NULL, hlc TEXT NOT NULL, payload TEXT NOT NULL, synced INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE setting (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    """,
    # v2: receipts (Snap) linked to transactions
    """
    CREATE TABLE receipt (
        id TEXT PRIMARY KEY, txn_id TEXT REFERENCES txn(id), merchant TEXT, date TEXT,
        total_minor INTEGER, currency TEXT NOT NULL DEFAULT 'ILS', raw_text TEXT,
        installments INTEGER NOT NULL DEFAULT 1, updated_hlc TEXT NOT NULL, is_deleted INTEGER NOT NULL DEFAULT 0);
    """,
]

SCHEMA_VERSION = len(MIGRATIONS)


class Database:
    def __init__(self, path: str | Path = ":memory:"):
        self.path = str(path)
        if self.path != ":memory:":
            Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(self.path, isolation_level=None, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA foreign_keys = ON")
        if self.path != ":memory:":
            self.conn.execute("PRAGMA journal_mode = WAL")
        self.migrate()

    @property
    def version(self) -> int:
        return self.conn.execute("PRAGMA user_version").fetchone()[0]

    def migrate(self, target: int = SCHEMA_VERSION) -> None:
        current = self.version
        if current > SCHEMA_VERSION:
            raise RuntimeError(f"database v{current} is newer than app (v{SCHEMA_VERSION})")
        for v in range(current, target):
            try:
                self.conn.execute("BEGIN")
                for stmt in filter(str.strip, MIGRATIONS[v].split(";")):
                    self.conn.execute(stmt)
                self.conn.execute(f"PRAGMA user_version = {v + 1}")
                self.conn.execute("COMMIT")
            except Exception:
                self.conn.execute("ROLLBACK")
                raise

    def close(self):
        self.conn.close()
