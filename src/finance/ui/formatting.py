"""UI-independent helpers (tested without Toga)."""
from __future__ import annotations

from decimal import Decimal, InvalidOperation


def parse_amount(text: str) -> Decimal:
    """Accepts '45', '45.9', '45,90', '1 234,50', '₪12'. Raises ValueError."""
    t = (text or "").replace("₪", "").replace("\u00a0", "").replace(" ", "").strip()
    if t.count(",") == 1 and "." not in t:
        t = t.replace(",", ".")
    t = t.replace(",", "")
    try:
        d = Decimal(t)
    except InvalidOperation:
        raise ValueError(f"не число: {text!r}") from None
    if d <= 0:
        raise ValueError("сумма должна быть больше нуля")
    return d


def sparkline(values: list[int], width: int = 30) -> str:
    """Text chart for the Runway summary (Toga Canvas is optional)."""
    if not values:
        return ""
    bars = "▁▂▃▄▅▆▇█"
    step = max(1, len(values) // width)
    pts = values[::step]
    lo, hi = min(pts), max(pts)
    span = (hi - lo) or 1
    return "".join(bars[int((v - lo) / span * (len(bars) - 1))] for v in pts)


def bar(fraction: float, width: int = 12) -> str:
    f = max(0.0, min(1.0, fraction))
    return "█" * round(f * width) + "░" * (width - round(f * width))
