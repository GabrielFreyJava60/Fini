"""Default seed categories. IDs are UUIDv5 of the system key, so they're stable on every device."""
from __future__ import annotations

import uuid
from dataclasses import dataclass

_NS = uuid.UUID("6f1c2b1e-8d7a-4b8e-9a51-3c0a7e2f9d10")


@dataclass(frozen=True, slots=True)
class SeedCategory:
    system_key: str
    name_he: str
    name_en: str
    name_ru: str
    kind: str  # expense | income
    essential: bool
    icon: str

    @property
    def id(self) -> str:
        return str(uuid.uuid5(_NS, f"category.{self.system_key}"))


SEED_CATEGORIES: tuple[SeedCategory, ...] = (
    SeedCategory("groceries", "מכולת וסופר", "Groceries", "Продукты", "expense", True, "🛒"),
    SeedCategory("housing", "דיור ושכירות", "Housing & Rent", "Жильё", "expense", True, "🏠"),
    SeedCategory("arnona", "ארנונה", "Arnona", "Арнона", "expense", True, "🏛"),
    SeedCategory("utilities", "חשמל, מים וגז", "Utilities", "Коммунальные", "expense", True, "💡"),
    SeedCategory("vaad_bayit", "ועד בית", "Building Committee", "Ваад байт", "expense", True, "🏢"),
    SeedCategory("transport", "תחבורה ודלק", "Transport & Fuel", "Транспорт", "expense", True, "🚗"),
    SeedCategory("health", "בריאות וקופת חולים", "Health", "Здоровье", "expense", True, "🩺"),
    SeedCategory("insurance", "ביטוח", "Insurance", "Страховка", "expense", True, "🛡"),
    SeedCategory("phone_internet", "סלולר ואינטרנט", "Phone & Internet", "Связь", "expense", True, "📱"),
    SeedCategory("education", "חינוך וגן", "Education & Kindergarten", "Образование", "expense", True, "🎓"),
    SeedCategory("dining", "מסעדות וקפה", "Dining & Coffee", "Кафе", "expense", False, "☕"),
    SeedCategory("shopping", "קניות", "Shopping", "Покупки", "expense", False, "🛍"),
    SeedCategory("entertainment", "בילוי ופנאי", "Entertainment", "Досуг", "expense", False, "🎬"),
    SeedCategory("subscriptions", "מנויים", "Subscriptions", "Подписки", "expense", False, "🔁"),
    SeedCategory("travel", "חופשות", "Travel", "Путешествия", "expense", False, "✈️"),
    SeedCategory("gifts", "מתנות ותרומות", "Gifts & Donations", "Подарки", "expense", False, "🎁"),
    SeedCategory("other_expense", "אחר", "Other", "Другое", "expense", False, "•"),
    SeedCategory("salary", "משכורת", "Salary", "Зарплата", "income", False, "💼"),
    SeedCategory("bituach_leumi", "ביטוח לאומי", "National Insurance", "Битуах леуми", "income", False, "🏦"),
    SeedCategory("other_income", "הכנסה אחרת", "Other Income", "Другой доход", "income", False, "➕"),
)
