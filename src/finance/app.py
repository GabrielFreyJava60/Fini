"""Briefcase entry point."""
from __future__ import annotations

from pathlib import Path

import toga

from .security import recovery, vault
from .security.keychain import keychain
from .storage import Database, LedgerRepository
from .ui.screens import BudgetsScreen, InsightsScreen, LedgerScreen, QuickAddScreen, SettingsScreen

DEK_ACCOUNT = "dek.v1"


class FinanceApp(toga.App):
    def startup(self):
        self.data_dir = Path(self.paths.data)
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.db = Database(self.data_dir / "ledger.sqlite3")
        self.repo = LedgerRepository(self.db)
        self.repo.seed_categories()
        self.keychain = keychain()
        self._pending_phrase = self._ensure_keys()

        self.views = [LedgerScreen(self), QuickAddScreen(self), BudgetsScreen(self), InsightsScreen(self), SettingsScreen(self)]
        titles = ["Журнал", "＋ Запись", "Бюджеты", "Прогноз", "Настройки"]
        self.main_window = toga.MainWindow(title=self.formal_name)
        self.main_window.content = toga.OptionContainer(
            content=[toga.OptionItem(t, s.box) for t, s in zip(titles, self.views)])
        self.refresh_all()
        self.main_window.content.current_tab = 1  # open straight on quick-add
        self.main_window.show()

    def _ensure_keys(self) -> str | None:
        """First launch: create DEK + recovery phrase, store DEK in Keychain, wrapped DEK in settings."""
        if self.keychain.get(DEK_ACCOUNT) is not None:
            return None
        phrase = recovery.generate_phrase()
        import os
        salt = os.urandom(16)
        dek = vault.new_dek()
        kek = vault.derive_kek(recovery.phrase_to_entropy(phrase), salt)
        self.repo.set_setting("vault_salt", salt.hex())
        self.repo.set_setting("vault_wrapped_dek", vault.wrap(dek, kek).hex())
        self.keychain.set(DEK_ACCOUNT, dek)
        return phrase

    def vault_phrase_once(self) -> str:
        phrase, self._pending_phrase = self._pending_phrase, None
        return phrase or "Фраза уже была показана. Её нельзя восстановить из приложения."

    def refresh_all(self):
        for s in self.views:
            s.refresh()


def main():
    return FinanceApp("Финансы", "com.gabrielfreidlin.finance")
