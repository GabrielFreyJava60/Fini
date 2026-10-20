"""Snap: deterministic Hebrew/English receipt parser + receipt↔transaction matcher."""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal, InvalidOperation
from difflib import SequenceMatcher

from .money import DEFAULT_CURRENCY, Money

TOTAL_KEYWORDS = ('סה"כ', "סה״כ", "סהכ", "לתשלום", "total", "סך הכל", "итого")
INSTALLMENT_KEYWORDS = ("תשלומים", "installments", "платеж")
_AMOUNT = re.compile(r"[\d.,]+")
_DATE = re.compile(r"\b(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})\b")


@dataclass(slots=True)
class Field:
    value: object
    confidence: float


@dataclass(slots=True)
class ReceiptDraft:
    extractor_id: str = "heuristic"
    merchant: Field | None = None
    date: Field | None = None
    total: Field | None = None
    installment_count: int = 1
    line_items: list[tuple[str, Money]] = field(default_factory=list)


def last_amount(line: str) -> Decimal | None:
    best = None
    for tok in _AMOUNT.findall(line):
        cleaned = tok.replace(",", "")
        if "." in cleaned:
            try:
                best = Decimal(cleaned)
            except InvalidOperation:
                pass
    return best


class HeuristicReceiptParser:
    id = "heuristic"

    def extract(self, ocr_text: str, currency: str = DEFAULT_CURRENCY) -> ReceiptDraft | None:
        d = ReceiptDraft(extractor_id=self.id)
        lines = [l for l in ocr_text.splitlines() if l.strip()]
        total_idx = None
        for idx in range(len(lines) - 1, -1, -1):
            low = lines[idx].lower()
            if any(k in low for k in TOTAL_KEYWORDS) and (amt := last_amount(lines[idx])) is not None:
                d.total = Field(Money(amt, currency), 0.75)
                total_idx = idx
                break
        for l in lines:
            if any(k in l.lower() for k in INSTALLMENT_KEYWORDS):
                nums = [int(n) for n in re.findall(r"\d+", l) if 2 <= int(n) <= 36]
                if nums:
                    d.installment_count = nums[0]
                    break
        for l in lines:
            if m := _DATE.search(l):
                dd, mm, yy = (int(x) for x in m.groups())
                yy += 2000 if yy < 100 else 0
                try:
                    d.date = Field(date(yy, mm, dd), 0.6)  # Israeli receipts are DD/MM/YYYY
                    break
                except ValueError:
                    continue
        if lines:
            d.merchant = Field(lines[0].strip(), 0.4)
        for l in lines[1:total_idx]:
            amt = last_amount(l)
            label = _AMOUNT.sub("", l).strip()
            if amt is not None and label and not _DATE.search(l):
                d.line_items.append((label, Money(amt, currency)))
        return d if d.total is not None else None


def _merchant_similarity(a: str | None, b: str | None) -> float:
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, a.casefold(), b.casefold()).ratio()


class ReceiptMatcher:
    """amount ±1 % (min 1 minor unit), date ±3 days, same currency."""

    def matches(self, receipt_total: Money, receipt_date: date, tx_amount: Money, tx_date: date) -> bool:
        if receipt_total.currency != tx_amount.currency:
            return False
        a, b = abs(receipt_total.minor_units), abs(tx_amount.minor_units)
        tol = max(1, a // 100)
        return abs(a - b) <= tol and abs((receipt_date - tx_date).days) <= 3

    def best_match(self, draft: ReceiptDraft, candidates):
        """candidates: iterable of objects with .amount (Money), .date (date), .payee. Returns best or None."""
        if draft.total is None:
            return None
        rdate = draft.date.value if draft.date else date.today()
        merchant = draft.merchant.value if draft.merchant else None
        ok = [c for c in candidates if self.matches(draft.total.value, rdate, c.amount, c.date)]
        return max(ok, key=lambda c: (_merchant_similarity(merchant, c.payee), -abs((c.date - rdate).days)), default=None)
