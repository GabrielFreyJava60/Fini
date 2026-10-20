"""Offline, rule-based assistant. No network, no LLM: keyword intents (RU/HE/EN) over the
numbers produced by Runway/Pulse/Snap. Numbers are only read from results, never invented.

Apple Foundation Models (on-device LLM) is a Swift-only API and can't be called from Python
directly. A future bridge would need a small Swift shim exposed to rubicon-objc (see README)."""
from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date, timedelta

from ..core.money import Money
from ..core.pulse import EXPLANATIONS
from ..core.receipts import HeuristicReceiptParser

INTENTS = {
    "runway": ("runway", "хват", "прогноз", "баланс", "зарплат", "позвол", "могу", "forecast", "balance", "afford",
               "תחזית", "יתרה", "מספיק"),
    "pulse": ("pulse", "стресс", "почему", "stress", "score", "why", "לחץ", "ציון", "למה"),
    "spend": ("потрат", "трат", "расход", "spent", "spend", "הוצאתי", "הוצאות"),
    "receipt": ('סה"כ', "סה״כ", "לתשלום", "total", "итого", "чек", "receipt", "קבלה"),
}
_NUM = re.compile(r"\d+(?:\.\d+)?")


@dataclass(slots=True)
class Answer:
    intent: str
    text: str


def detect_lang(q: str) -> str:
    if re.search(r"[\u0590-\u05FF]", q):
        return "he"
    if re.search(r"[А-Яа-яЁё]", q):
        return "ru"
    return "en"


def _t(lang, ru, he, en):
    return {"ru": ru, "he": he, "en": en}[lang]


class Assistant:
    def __init__(self, repo, compute_fn=None, today: date | None = None):
        from ..core.insights import compute
        self.repo, self._compute, self.today = repo, compute_fn or compute, today or date.today()

    def classify(self, q: str) -> str:
        low = q.lower()
        if "\n" in q and any(k in low for k in INTENTS["receipt"]):
            return "receipt"
        if _NUM.search(q) and any(w in low for w in ("afford", "могу", "позвол", "יכול")):
            return "runway"
        scores = {k: sum(w in low for w in ws) for k, ws in INTENTS.items()}
        best = max(scores, key=scores.get)
        return best if scores[best] else "help"

    def ask(self, q: str) -> Answer:
        q = (q or "").strip()
        intent = self.classify(q) if q else "help"
        return Answer(intent, getattr(self, f"_{intent}")(q, detect_lang(q)))

    def _help(self, q, lang):
        return _t(lang,
                  "Я работаю офлайн и отвечаю про прогноз (Runway), стресс-индекс (Pulse), траты и чеки. "
                  "Например: «Хватит до зарплаты?», «Могу потратить 500?», «Почему стресс высокий?», «Сколько потратил за неделю?»",
                  "אפשר לשאול על תחזית, ציון לחץ, הוצאות או להדביק קבלה.",
                  "Ask about your forecast, stress score, spending, or paste a receipt.")

    def _runway(self, q, lang):
        rr, _, _ = self._compute(self.repo, self.today)
        f = lambda m: Money.from_minor(m, rr.currency).format()
        low_p10 = min(rr.p10)
        nums = _NUM.findall(q.replace(",", ""))
        if nums and any(w in q.lower() for w in ("afford", "могу", "позвол", "יכול")):
            spend = Money(nums[0], rr.currency).minor_units
            left = low_p10 - spend
            return _t(lang,
                      f"Если потратить {f(spend)}, в пессимистичном сценарии (P10) минимум будет {f(left)} — "
                      + ("укладываетесь." if left >= 0 else "есть риск уйти в минус."),
                      f"אחרי {f(spend)} המינימום הפסימי יהיה {f(left)}.",
                      f"After spending {f(spend)}, the pessimistic (P10) low would be {f(left)}.")
        risk = round(rr.probability_below_zero * 100)
        day = rr.first_risky_day()
        risky = "" if day is None else (self.today + timedelta(days=day)).strftime("%d.%m")
        n = len(rr.p50)
        return _t(lang,
                  f"Через {n} дн. ожидаемый баланс {f(rr.p50[-1])}; пессимистичный минимум {f(low_p10)}. "
                  f"Вероятность уйти в минус: {risk}%." + (f" Первый рискованный день: {risky}." if risky else ""),
                  f"יתרה צפויה בעוד {n} ימים: {f(rr.p50[-1])}. מינימום פסימי: {f(low_p10)}. סיכון למינוס: {risk}%.",
                  f"Expected balance in {n} days: {f(rr.p50[-1])}; pessimistic low {f(low_p10)}; chance of going negative {risk}%.")

    def _pulse(self, q, lang):
        _, sb, _ = self._compute(self.repo, self.today)
        bands = {"calm": ("спокойно", "רגוע", "calm"), "watch": ("внимание", "שים לב", "watch"),
                 "elevated": ("повышенный", "גבוה", "elevated")}[sb.band]
        top = [(k, p) for k, p in sb.contributions() if p >= 1][:2]
        why = "; ".join(f"{EXPLANATIONS[k][0 if lang == 'ru' else 1]} (+{p:.0f})" for k, p in top) or "—"
        return _t(lang, f"Pulse: {sb.score}/100 ({bands[0]}). Главные причины: {why}.",
                  f"Pulse: {sb.score}/100 ({bands[1]}). {why}.",
                  f"Pulse: {sb.score}/100 ({bands[2]}). Main drivers: {why}.")

    def _spend(self, q, lang):
        low = q.lower()
        days = 7 if any(w in low for w in ("недел", "week", "שבוע")) else \
            1 if any(w in low for w in ("сегодня", "today", "היום")) else 30
        start = self.today - timedelta(days=days - 1)
        txs = self.repo.transactions(start, self.today + timedelta(days=1))
        s = Money.from_minor(-sum(t.amount.minor_units for t in txs if t.kind == "expense")).format()
        return _t(lang, f"За последние {days} дн. расходы: {s}.", f"הוצאות ב-{days} הימים האחרונים: {s}.",
                  f"Spent in the last {days} days: {s}.")

    def _receipt(self, q, lang):
        d = HeuristicReceiptParser().extract(q)
        if d is None:
            return _t(lang, "Не нашёл итоговую сумму в чеке.", "לא נמצא סכום כולל.", "No total found.")
        parts = [f"{d.merchant.value if d.merchant else '?'}: {d.total.value.format()}"]
        if d.installment_count > 1:
            per = d.total.value.allocate(d.installment_count)
            parts.append(f"{d.installment_count} × {per[-1].format()} (1-й: {per[0].format()})")
        if d.line_items:
            parts.append(", ".join(f"{n} {m.format()}" for n, m in d.line_items[:5]))
        return " · ".join(parts)
