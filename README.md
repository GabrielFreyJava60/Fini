# Финансы — Python / BeeWare версия

Личный бюджет и прогноз денежного потока для iPhone на **Python + BeeWare (Toga + Briefcase)**.
Порт Swift-проекта `finance-app/` (он сохранён без изменений). App ID-заглушка: `com.gabrielfreidlin.finance` — замените на свой.

## Структура

```
src/finance/
  core/        чистый Python: Money (Decimal, агороты, банковское округление), карты и ташлумим,
               Runway (Monte Carlo, seed), Pulse (стресс-индекс), парсер чеков на иврите + матчер,
               стартовые категории (иврит/англ/рус, стабильные UUIDv5), insights (Runway/Pulse из журнала)
  storage/     SQLite (sqlite3): схема + миграции (PRAGMA user_version), soft delete, журнал событий,
               HLC-часы, репозиторий, слияние конфликтов (LWW по полям)
  security/    фраза восстановления (24 слова BIP39, словарь в resources/), HKDF/scrypt, AES-GCM,
               AES-KeyWrap, шифрованный экспорт, мост к iOS Keychain через rubicon-objc
  ui/          экраны Toga: Журнал, Быстрая запись, Бюджеты, Прогноз (Runway + Pulse + ассистент), Настройки
  assistant/   офлайн-ассистент на правилах (RU/HE/EN), без сети
tests/         pytest (50 тестов, включая smoke-тест UI на toga-dummy)
```

## Запуск на Linux/Mac для разработки

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install briefcase pytest cryptography toga-dummy
python -m pytest            # все тесты
briefcase dev               # десктоп-версия (на Linux нужны GTK-зависимости, см. сообщение briefcase)
```

## Сборка под iPhone (только Mac с Xcode)

```bash
pip install briefcase
briefcase create iOS        # создаёт Xcode-проект, скачивает Python для iOS и колёса
briefcase build iOS
briefcase run iOS           # симулятор; выбрать устройство: briefcase run iOS -d "iPhone 17"
briefcase open iOS          # открыть в Xcode → Signing & Capabilities → ваша команда → запуск на телефоне
briefcase package iOS       # для App Store / TestFlight
```

`cryptography` собирается не из исходников: BeeWare публикует готовые iOS-колёса в своём репозитории
(подтверждено их новостями за ноябрь 2025). Если `briefcase create iOS` всё же напишет
«Cannot compile native modules», значит колеса для вашей версии Python нет — тогда временно снизьте версию Python.

## Что потеряно по сравнению со Swift

| Было в Swift | В Python/BeeWare |
|---|---|
| Liquid Glass, SwiftUI-анимации, тактильная отдача | Обычные нативные UIKit-виджеты через Toga, без стекла и кастомных эффектов |
| Виджеты (WidgetKit), экран блокировки | Нет. Расширения iOS нельзя написать на Python |
| Action button / App Intents / Siri / Shortcuts | Нет. Замена: приложение открывается сразу на «Быстрой записи» (сумма-чип → категория → Сохранить, ~3 нажатия) |
| Синхронизация CloudKit с шифрованием на устройстве | Нет синхронизации. Есть журнал событий, HLC и слияние конфликтов (готово для будущей синхронизации) + шифрованный экспорт-файл |
| Foundation Models (on-device LLM Apple) | Недоступно из Python: это Swift-only API. Сейчас — ассистент на правилах. В будущем: маленькая Swift-обёртка, вызываемая через rubicon-objc |
| VisionKit/Vision OCR для чеков | Нет камеры/OCR; парсер работает с текстом (вставка в ассистента) |
| iCloud Keychain (синхронизация ключа) | Ключ в Keychain только на этом устройстве (`WhenUnlockedThisDeviceOnly`). Восстановление — фразой из 24 слов |
| SwiftData | SQLite |

## Безопасность

- Ключ данных (DEK, AES-256) хранится в iOS Keychain; обёрнутая копия (AES-KeyWrap ключом из фразы через HKDF) — в базе.
- Фраза показывается **один раз** (Настройки → «Показать фразу восстановления»). Восстановление по фразе в UI ещё не сделано: функции есть (`recovery.phrase_to_entropy`, `vault.unwrap`), экрана нет.
- Экспорт: файл `.finv` (scrypt N=2^15 + AES-GCM, заголовок защищён как AAD).
- **Сама база SQLite не шифруется** (нет SQLCipher-колеса для iOS). Её защищает шифрование файлов iOS (Data Protection), пока телефон заблокирован.
- Keychain-мост (`security/keychain.py`) **не проверен на устройстве**: на iOS ошибка доступа к Keychain останавливает запуск, чтобы не потерять ключ молча. Вне iOS используется ключ в памяти, и в настройках показывается предупреждение.

## Не проверено

- Сборка `briefcase create/build/run iOS` (нужен Mac), работа Keychain через rubicon-objc, вид экранов на iPhone.
- `briefcase dev` на этом Linux-компьютере остановился на отсутствии GTK-зависимостей; конфигурацию Briefcase он прочитал без ошибок.

## App Store

Release prep lives in `docs/app-store/` (start with `SUBMISSION.md`), privacy policy in `docs/privacy-policy.md`, privacy manifest in `ios/PrivacyInfo.xcprivacy`, icon in `src/finance/resources/icons/` (`scripts/make_icon.py`).
