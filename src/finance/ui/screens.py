"""Toga screens. Each builder returns a Box; `refresh()` rebuilds from the repository."""
from __future__ import annotations

from datetime import date

import toga
from toga.style import Pack

from ..assistant import Assistant
from ..core.insights import compute
from ..core.money import Money
from ..core.pulse import EXPLANATIONS
from .formatting import bar, parse_amount, sparkline

COL = Pack(direction="column", margin=10)
ROW = Pack(direction="row", margin=(4, 0))
TITLE = Pack(font_size=20, font_weight="bold", margin_bottom=8)
QUICK_AMOUNTS = ("20", "50", "100", "200")


def _cat_name(c) -> str:
    return f"{c['icon']} {c['name_ru'] or c['name_en']} · {c['name_he']}"


class LedgerScreen:
    def __init__(self, app):
        self.app = app
        self.table = toga.Table(headings=["Дата", "Сумма", "Категория", "Получатель"], style=Pack(flex=1),
                                accessors=["date", "amount", "category", "payee"])
        self.balance = toga.Label("", style=TITLE)
        undo = toga.Button("↶ Отменить последнее", on_press=self.undo)
        delete = toga.Button("Удалить выбранное", on_press=self.delete)
        self.box = toga.Box(children=[self.balance, toga.Box(children=[undo, delete], style=ROW), self.table], style=COL)

    def refresh(self):
        repo = self.app.repo
        cats = {c["id"]: c for c in repo.categories()}
        self.balance.text = f"Баланс: {repo.balance().format()}"
        self.table.data = [{"date": t.date.strftime("%d.%m"), "amount": t.amount.format(),
                            "category": _cat_name(cats[t.category_id]) if t.category_id in cats else "—",
                            "payee": t.payee or "", "id": t.id} for t in repo.transactions(limit=300)]

    def undo(self, _w):
        if self.app.repo.undo_last():
            self.app.refresh_all()

    def delete(self, _w):
        row = self.table.selection
        if row is not None:
            self.app.repo.delete_transaction(row.id)
            self.app.refresh_all()


class QuickAddScreen:
    """Target ≈ 3 taps: amount chip (or type) → category → Save. Defaults: expense, today."""

    def __init__(self, app):
        self.app = app
        self.amount = toga.TextInput(placeholder="Сумма, ₪", style=Pack(flex=1, font_size=24))
        chips = [toga.Button(f"₪{a}", on_press=self._chip(a), style=Pack(flex=1)) for a in QUICK_AMOUNTS]
        self.kind = toga.Switch("Доход", value=False)
        self.category = toga.Selection(accessor="label", style=Pack(flex=1))
        self.payee = toga.TextInput(placeholder="Где (необязательно)")
        self.status = toga.Label("")
        save = toga.Button("Сохранить", on_press=self.save, style=Pack(font_size=20, margin_top=10))
        self.box = toga.Box(children=[toga.Label("Быстрая запись", style=TITLE), self.amount,
                                      toga.Box(children=chips, style=ROW), self.kind, self.category,
                                      self.payee, save, self.status], style=COL)

    def _chip(self, a):
        def h(_w):
            self.amount.value = a
        return h

    def refresh(self):
        self.category.items = [{"label": _cat_name(c), "id": c["id"]} for c in self.app.repo.categories()]

    def save(self, _w):
        try:
            amt = parse_amount(self.amount.value)
        except ValueError as e:
            self.status.text = f"⚠️ {e}"
            return
        kind = "income" if self.kind.value else "expense"
        sel = self.category.value
        self.app.repo.add_transaction(Money(amt), kind, category_id=sel.id if sel else None,
                                      payee=self.payee.value or None)
        self.status.text = f"✓ {Money(amt).format()}"
        self.amount.value, self.payee.value = "", ""
        self.app.refresh_all()


class BudgetsScreen:
    def __init__(self, app):
        self.app = app
        self.list = toga.Box(style=Pack(direction="column"))
        self.category = toga.Selection(accessor="label")
        self.limit = toga.TextInput(placeholder="Лимит на месяц, ₪")
        add = toga.Button("Установить лимит", on_press=self.set_limit)
        self.box = toga.Box(children=[toga.Label("Бюджеты", style=TITLE), toga.ScrollContainer(content=self.list, style=Pack(flex=1)),
                                      self.category, self.limit, add], style=COL)

    @property
    def month(self):
        return date.today().strftime("%Y-%m")

    def refresh(self):
        self.category.items = [{"label": _cat_name(c), "id": c["id"]} for c in self.app.repo.categories("expense")]
        self.list.clear()
        for cat, limit, spent in self.app.repo.budget_status(self.month):
            frac = spent.minor_units / limit.minor_units if limit.minor_units else 0
            warn = " ⚠️" if frac > 1 else ""
            self.list.add(toga.Label(f"{cat['icon']} {cat['name_ru']}  {bar(frac)}  {spent.format()} / {limit.format()}{warn}"))

    def set_limit(self, _w):
        sel = self.category.value
        try:
            amt = parse_amount(self.limit.value)
        except ValueError:
            return
        if sel:
            self.app.repo.set_budget(sel.id, self.month, Money(amt))
            self.limit.value = ""
            self.refresh()


class InsightsScreen:
    """Runway summary + Pulse score with 'why' + offline assistant."""

    def __init__(self, app):
        self.app = app
        self.runway = toga.MultilineTextInput(readonly=True, style=Pack(height=150))
        self.pulse = toga.MultilineTextInput(readonly=True, style=Pack(height=170))
        self.q = toga.TextInput(placeholder="Спросите: «Хватит до зарплаты?»", on_confirm=self.ask)
        self.a = toga.MultilineTextInput(readonly=True, style=Pack(flex=1))
        self.box = toga.Box(children=[toga.Label("Runway", style=TITLE), self.runway, toga.Label("Pulse", style=TITLE),
                                      self.pulse, toga.Label("Ассистент (офлайн)", style=TITLE), self.q,
                                      toga.Button("Спросить", on_press=self.ask), self.a], style=COL)

    def refresh(self):
        rr, sb, _ = compute(self.app.repo, paths=500)
        f = lambda m: Money.from_minor(m, rr.currency).format()
        self.runway.value = (f"30 дней: {sparkline(rr.p50)}\n"
                             f"Ожидаемо (P50): {f(rr.p50[-1])}\nДиапазон: {f(rr.p10[-1])} … {f(rr.p90[-1])}\n"
                             f"Риск минуса: {rr.probability_below_zero:.0%}")
        lines = [f"{sb.score}/100 · {sb.band}"] + [f"{bar(sb.components[k], 8)} +{p:.0f}  {EXPLANATIONS[k][0]}"
                                                    for k, p in sb.contributions()]
        self.pulse.value = "\n".join(lines)

    def ask(self, _w):
        self.a.value = Assistant(self.app.repo).ask(self.q.value).text


class SettingsScreen:
    def __init__(self, app):
        self.app = app
        self.buffer = toga.TextInput(placeholder="Подушка безопасности, ₪")
        self.passphrase = toga.PasswordInput(placeholder="Пароль для экспорта")
        self.info = toga.MultilineTextInput(readonly=True, style=Pack(flex=1))
        self.box = toga.Box(children=[
            toga.Label("Настройки", style=TITLE), self.buffer,
            toga.Button("Сохранить подушку", on_press=self.save_buffer),
            toga.Button("Показать фразу восстановления", on_press=self.show_phrase),
            self.passphrase, toga.Button("Экспорт (зашифрованный)", on_press=self.export), self.info], style=COL)

    def refresh(self):
        kc = self.app.keychain
        self.info.value = ("Ключи: iOS Keychain" if kc.is_secure else
                           "⚠️ Режим разработки: ключи в памяти, не в Keychain") + f"\nБаза: {self.app.db.path}"

    def save_buffer(self, _w):
        try:
            self.app.repo.set_setting("buffer_minor", Money(parse_amount(self.buffer.value)).minor_units)
            self.app.refresh_all()
        except ValueError as e:
            self.info.value = str(e)

    def show_phrase(self, _w):
        self.info.value = ("Запишите на бумаге и храните офлайн:\n\n" + self.app.vault_phrase_once()) or ""

    def export(self, _w):
        from ..security.vault import export_ledger
        if len(self.passphrase.value or "") < 8:
            self.info.value = "Пароль минимум 8 символов"
            return
        out = self.app.data_dir / f"finance-backup-{date.today():%Y%m%d}.finv"
        out.write_bytes(export_ledger(self.app.repo, self.passphrase.value))
        self.passphrase.value = ""
        self.info.value = f"Сохранено: {out}"
