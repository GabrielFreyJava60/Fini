"""Exact money: Decimal for arithmetic, int minor units (agorot/cents) for storage."""
from __future__ import annotations

from dataclasses import dataclass
from decimal import ROUND_HALF_EVEN, Decimal, InvalidOperation

DEFAULT_CURRENCY = "ILS"
_ZERO_DIGIT = {"JPY", "KRW", "VND", "CLP", "ISK", "UGX", "XAF", "XOF"}
_THREE_DIGIT = {"BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"}


class MoneyError(ValueError):
    pass


class CurrencyMismatch(MoneyError):
    def __init__(self, a: str, b: str):
        super().__init__(f"currency mismatch: {a} vs {b}")
        self.a, self.b = a, b


def normalize_currency(code: str) -> str:
    code = (code or "").strip().upper()
    if len(code) != 3 or not code.isascii() or not code.isalpha():
        raise MoneyError(f"malformed ISO 4217 code: {code!r}")
    return code


def minor_digits(code: str) -> int:
    code = normalize_currency(code)
    if code in _ZERO_DIGIT:
        return 0
    if code in _THREE_DIGIT:
        return 3
    return 2


def _to_decimal(value) -> Decimal:
    if isinstance(value, float):
        raise TypeError("float is not allowed for money; pass str, int or Decimal")
    try:
        return Decimal(value)
    except (InvalidOperation, TypeError) as exc:
        raise MoneyError(f"invalid amount: {value!r}") from exc


@dataclass(frozen=True, slots=True)
class Money:
    amount: Decimal
    currency: str = DEFAULT_CURRENCY

    def __post_init__(self):
        object.__setattr__(self, "amount", _to_decimal(self.amount))
        object.__setattr__(self, "currency", normalize_currency(self.currency))

    @classmethod
    def from_minor(cls, minor: int, currency: str = DEFAULT_CURRENCY) -> "Money":
        return cls(Decimal(int(minor)).scaleb(-minor_digits(currency)), currency)

    @classmethod
    def zero(cls, currency: str = DEFAULT_CURRENCY) -> "Money":
        return cls(Decimal(0), currency)

    @property
    def minor_units(self) -> int:
        """Banker's rounding to the currency's minor unit."""
        scaled = self.amount.scaleb(minor_digits(self.currency))
        return int(scaled.quantize(Decimal(1), rounding=ROUND_HALF_EVEN))

    @property
    def is_negative(self) -> bool:
        return self.amount < 0

    def _check(self, other: "Money"):
        if not isinstance(other, Money):
            raise TypeError("can only combine Money with Money")
        if other.currency != self.currency:
            raise CurrencyMismatch(self.currency, other.currency)

    def __add__(self, other: "Money") -> "Money":
        self._check(other)
        return Money(self.amount + other.amount, self.currency)

    def __sub__(self, other: "Money") -> "Money":
        self._check(other)
        return Money(self.amount - other.amount, self.currency)

    def __neg__(self) -> "Money":
        return Money(-self.amount, self.currency)

    def __abs__(self) -> "Money":
        return Money(abs(self.amount), self.currency)

    def __lt__(self, other: "Money") -> bool:
        self._check(other)
        return self.amount < other.amount

    def __eq__(self, other) -> bool:
        return isinstance(other, Money) and self.currency == other.currency and self.amount == other.amount

    def __hash__(self):
        return hash((self.amount.normalize(), self.currency))

    def times(self, factor) -> "Money":
        return Money(self.amount * _to_decimal(factor), self.currency)

    def converted(self, target: str, rate) -> "Money":
        """1 unit of self.currency = `rate` units of target (explicit, never implicit)."""
        return Money(self.amount * _to_decimal(rate), target)

    def allocate(self, count: int) -> list["Money"]:
        """Split into `count` parts summing exactly; leftover minor units go to the FIRST parts
        (Israeli issuers put tashlumim rounding on the first payment)."""
        if count <= 0:
            raise MoneyError(f"invalid allocation count: {count}")
        total = self.minor_units
        sign = -1 if total < 0 else 1
        base, rem = divmod(abs(total), count)
        return [Money.from_minor(sign * (base + (1 if i < rem else 0)), self.currency) for i in range(count)]

    def format(self) -> str:
        symbols = {"ILS": "₪", "USD": "$", "EUR": "€", "GBP": "£"}
        q = Decimal(1).scaleb(-minor_digits(self.currency))
        num = f"{self.amount.quantize(q, rounding=ROUND_HALF_EVEN):,}"
        return f"{symbols.get(self.currency, self.currency + ' ')}{num}"

    def __str__(self) -> str:
        return f"{self.amount} {self.currency}"
