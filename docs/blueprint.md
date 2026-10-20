# Next-Gen iOS Personal Finance App — Strategy & Engineering Blueprint

**Prepared for:** Gabriel Freidlin
**Date:** 20 Oct 2026
**Voice:** Principal iOS Engineer · Product Designer · Fintech Strategist
**Working codename:** *Ledgerlight* (placeholder)

> **Read this first: one premise correction.** The brief treats iOS 27 as unannounced. It isn't. Apple showed iOS 27 at WWDC26 and shipped it on **14 Sep 2026** ([Apple Newsroom](https://www.apple.com/newsroom/2026/09/major-updates-for-apples-software-platforms-are-now-available/)). Liquid Glass (introduced in iOS 26) is still the design language. iOS 27 adds a user slider that runs from "ultraclear" to "fully tinted," plus changes to materials, typography, and tab/navigation bars ([WWDC26 iOS guide](https://developer.apple.com/wwdc26/guides/ios/)). For developers, iOS 27 also brings a bigger Foundation Models framework (multimodal prompts, Vision OCR as model tools, Private Cloud Compute access for small developers), a new **Core AI** framework, and widgets you can configure through App Intents. So this document builds on **shipped** iOS 26/27 APIs. Anything that goes past them is marked **🔮 SPECULATIVE**.

**Rule used for sources:** Every price and stat links to a source. If I couldn't verify a figure from a primary or recent source, it's marked **(unverified)**. Prices are list prices seen in Oct 2026 and can vary by region, tax, and promotion.

---

## Table of Contents
1. [Phase 1 — Competitor Analysis](#phase-1--competitor-analysis)
2. [Phase 2 — Unique Value Proposition](#phase-2--unique-value-proposition-uvp)
3. [Phase 3a — Design System](#phase-3a--design-system)
4. [Phase 3b — Tech Stack & Architecture](#phase-3b--tech-stack--architecture)
5. [Phase 3c — Core User Flows](#phase-3c--core-user-flows)
6. [MVP Roadmap](#mvp-roadmap)
7. [Key Risks & Mitigations](#key-risks--mitigations)
8. [Sources](#sources)

---

# Phase 1 — Competitor Analysis

## 1.1 Landscape at a glance

The market splits into four groups:
- **Methodology-first:** YNAB. Sells a philosophy, zero-based budgeting.
- **Aggregator dashboards:** Monarch, Copilot, Rocket Money. These sell automation and depend on Plaid, MX, or Finicity.
- **Power-user ledgers:** MoneyWiz, Banktivity. These sell depth and look like desktop accounting software.
- **Lightweight trackers:** Spendee. Sells pretty charts at a low price.

None of them **predicts**. Each one tells you where money *went*, and none simulates where it *will go*. Every aggregator inherits the same sync fragility.

## 1.2 Per-competitor deep dive

### YNAB (You Need A Budget)
- **Pricing:** $14.99/mo or $109/yr (USD, plus tax), 34-day free trial with no card required, up to 6 people on one plan ([ynab.com/pricing](https://www.ynab.com/pricing); [Finpresso, Oct 2026](https://finpresso.com/reviews/ynab-review)).
- **Core strengths**
  - A clear behavioral method ("give every dollar a job") with a strong community and lots of education.
  - Household sharing at no extra cost. Investopedia ranks it "Best Overall" ([Investopedia, Oct 2026](https://www.investopedia.com/the-best-budgeting-apps-11725751)).
- **Critical flaws / UX pain points**
  - **Steep learning curve.** Reddit has recurring threads like "2 months into YNAB and I still feel lost" ([r/ynab](https://www.reddit.com/r/ynab/comments/1r2k0vt/2_months_into_ynab_and_i_still_feel_lost_thinking/)).
  - **Subscription fatigue.** Users track a pattern of repeated price increases ([r/ynab "price evolution"](https://www.reddit.com/r/ynab/comments/1vxrcq6/ynab_price_evolution/)).
  - **Rigid methodology.** It punishes users who don't want envelope discipline. It looks backward and forward only through manual targets. There's no predictive cash-flow model.
  - **Import reliability.** Users report missing or duplicate imported transactions ([Trustpilot](https://www.trustpilot.com/review/ynab.com)). Direct import only works with some banks.
  - **Thin investment tracking.** Per Investopedia, it doesn't sync investment accounts continuously.

### Copilot Money
- **Pricing:** $13/mo or $95/yr ($7.92/mo billed yearly), one-month trial, no free tier after it ([copilot.money](https://www.copilot.money/); [FinCompareLab](https://www.fincomparelab.com/reviews/copilot-money-review/)). Runs on iPhone, iPad, Mac, and web. **No Android. Requires US-based accounts** ([Copilot FAQ](https://www.copilot.money/faq)).
- **Core strengths**
  - The best-looking Apple-native design in the category.
  - AI auto-categorization and recurring-charge detection.
  - Positioned as private, with no ads.
- **Critical flaws / UX pain points.** These come from a coded dataset of 1-2★ App Store reviews, Aug–Nov 2025 ([CashJot coded reviews CSV](https://www.cashjot.com/research/budgeting-app-reviews/coded.csv)):
  - **Performance:** "laggy since update," "iOS26 performance unusable," crashes when reviewing about 1,100 transactions. There's also a 2026 Reddit thread titled "The iOS App Is Slow!" ([r/copilotmoney](https://www.reddit.com/r/copilotmoney/comments/1wcu6gn/to_the_devs_the_ios_app_is_slow/)).
  - **Sync:** "must re-auth accounts every session," "Apple Card transactions not updating," "duplicated every Apple Card transaction."
  - **Categorization:** "AI categorizes everything as Other," "auto recategorization overrides user," "AI categories unusable; no rules." This is rigid or opaque categorization in its worst form: the AI overrides the user.
  - **Pricing transparency:** "connects banks before disclosing price."
  - **No forecasting:** "no income categories or forecast."
  - **Couples:** each person needs their own subscription ([FinCompareLab](https://www.fincomparelab.com/reviews/copilot-money-review/)).

### Monarch Money
- **Pricing:** Core is $14.99/mo or $99.99/yr. Plus is $199.99/yr. The 7-day trial now requires a payment method ([FinCompareLab](https://www.fincomparelab.com/reviews/monarch-money-review/); [EnvelopeBudgeting](https://envelopebudgeting.com/articles/monarch-money-review)).
- **Core strengths**
  - The widest dashboard: net worth, investments, goals.
  - Unlimited household collaboration.
  - **Three data providers** (Plaid, Mastercard Data Connect/Finicity, MX) with manual provider switching.
  - A public connection-status dashboard and SOC 2 Type 2.
- **Critical flaws / UX pain points**
  - **Bank sync is the #1 complaint.** One Reddit post reads: "Crippling amounts of account sync errors... up to eight unique error failure modes across three accounts... Customer support is AI" ([r/MonarchMoney, Feb 2026](https://www.reddit.com/r/MonarchMoney/comments/1r4veod/crippling_amounts_of_account_sync_errors/)). Another: "Instead of new AI features, how about focusing on... the syncing" ([r/MonarchMoney, May 2026](https://www.reddit.com/r/MonarchMoney/comments/1tln786/another_monthmore_connection_issues/)).
  - **Value erosion.** A long-time user says 529 accounts stopped syncing and goals are "hit-or-miss" ([r/MonarchMoney, Jul 2026](https://www.reddit.com/r/MonarchMoney/comments/1ul6lfh/longtime_user_struggling_with_valueis_it_time_to/)).
  - **Retrospective by nature.** "It tracks money after the fact — it doesn't stop overspending before it happens" ([EnvelopeBudgeting](https://envelopebudgeting.com/articles/monarch-money-review)).
  - Reauthorization every 30–90 days is normal for many banks (same source).

### MoneyWiz (SilverWiz)
- **Pricing:** The current site lists Standard (cloud sync) at $29.99/yr and Premium (bank sync for "40,000 banks") at $59.99/yr or $5.99/mo ([wiz.money/pricing](https://www.wiz.money/pricing)). **The US App Store description still says $19.99 / $49.99 / $4.99** ([App Store](https://apps.apple.com/us/app/moneywiz-2026-personal-finance/id1511185140)). Treat the website as current. The App Store pricing is **(unverified/inconsistent)**. Manual tracking is free.
- **Core strengths**
  - Huge feature set: envelope budgets, 30+ reports, investments and crypto, multi-currency, OFX/QIF/CSV/MT940 import.
  - Apple Wallet integration and a native app on every Apple platform.
  - 4.6★ on the US App Store.
- **Critical flaws / UX pain points**
  - **Overwhelming UI.** The Balance calls the number of features and options "overwhelming" ([The Balance](https://www.thebalancemoney.com/a-review-of-moneywiz-2-2386064)).
  - **Bank feeds keep breaking.** "repeatedly have to reconnect my bank feeds... shows the wrong amounts" ([Setapp reviews, Jun 2026](https://setapp.com/apps/moneywiz/customer-reviews)). Support for ANZ Bank was dropped (same source).
  - **Trust and privacy.** Users flag a sign-in flow that asks for Apple ID or iCloud passwords in a pop-up as a phishing-like pattern (Setapp reviews, Apr and Sep 2026).
  - Some actions need the app restarted (Setapp reviews).

### Banktivity (IGG Software)
- **Pricing:** billed annually. Bronze $6.99/mo, Silver $8.99/mo, Gold $10.99/mo. Gold adds multi-currency and crypto. 30-day trial with no card ([banktivity.com/plans](https://www.banktivity.com/content/plans/plans.php)).
- **Core strengths**
  - Quicken-class depth on Mac: investments, real estate, check printing, reconciliation.
  - Apple-only focus.
- **Critical flaws / UX pain points**
  - **Desktop-first.** iPhone is a companion app, and the mental model is accounting, not lifestyle.
  - **Sync reliability.** App Store reviews cite silent download failures, stale balances, and Cloud Sync problems on iPhone ([App Store UK reviews](https://apps.apple.com/gb/app/banktivity-budget-finances/id1480779512?platform=iphone&see-all=reviews); [JustUseApp](https://justuseapp.com/en/app/1480779512/banktivity/reviews)). Support keeps a daily-updated list of known **Yodlee** connection issues ([Banktivity support](https://www.banktivity.com/support/articles/app/ibank-for-iphone/)).
  - No phone support (same).

### Spendee (Cleevio)
- **Pricing:** Premium is $5.99/mo or $35.99/yr with a 7-day trial ([spendee.com/pricing](https://www.spendee.com/pricing)). A Plus tier at $1.99/mo or $14.99/yr is reported by [MakerStack](https://makerstack.co/reviews/spendee-review/) but wasn't confirmed on the pricing page snippet **(partially unverified)**.
- **Core strengths**
  - Low price and attractive charts.
  - Shared wallets, multi-currency, and strong European bank coverage.
  - Fast manual entry.
- **Critical flaws / UX pain points**
  - **Sync and data loss.** One user says "Spendee deleted years of data" ([Trustpilot, 2026](https://www.trustpilot.com/review/spendee.com)). Sync silently stops for weeks (same). "bank sync almost never works" ([Capterra](https://www.capterra.com/p/238829/Spendee/reviews/)).
  - Pending transactions can't be edited until the bank confirms them (Capterra).
  - "Getting worse and slower with every update" (Trustpilot). Users who bought lifetime Premium still see upsell ads ([appy.fyi](https://appy.fyi/faq/com.cleevio.spendee)).
  - Capterra reviewers say there's no widget and no iPad version (2023 review, possibly outdated, **unverified today**).

### Rocket Money (relevant adjacent player)
- **Pricing:** there's a free tier. Premium is pay-what-you-want, roughly $7–$14/mo. Premium+ is $15/mo with the "Rowan" AI assistant. Bill-negotiation success fees (35–60% of first-year savings) are reportedly being replaced on 2 Nov 2026 ([Rocket Money](https://www.rocketmoney.com/learn/personal-finance/how-much-does-rocket-money-cost); [CNBC Select](https://www.cnbc.com/select/rocket-money-review/); [SaaSSwitcher](https://www.saasswitcher.com/blog/rocket-money-reviews)). Exact current tiers are **partially unverified**.
- **Strengths:** subscription detection and cancellation concierge.
- **Flaws:** surprise Premium charges, hard-to-reach human support, and negotiation fees ([Trustpilot](https://www.trustpilot.com/review/rocketmoney.com)). The business model is upsell-driven, and that clashes with privacy positioning.

### Local relevance: RiseUp (Israel)
- An Israeli cash-flow app. It connects to banks and credit cards over Israeli open banking with read-only, revocable consent and no password sharing. Listed at about ₪55/mo after a free month ([riseup.co.il](https://www.riseup.co.il/questions/)). Older sources say ₪45 **(price varies)**.
- **Why it matters:** this is the incumbent you'd face at home. It's coaching and cash-flow oriented, web/app hybrid, and Hebrew-first. It isn't an iOS-native, privacy-first experience.

## 1.3 Comparison table

| Dimension | YNAB | Copilot | Monarch | MoneyWiz | Banktivity | Spendee | Rocket Money |
|---|---|---|---|---|---|---|---|
| **Annual price (USD)** | $109 | $95 | $99.99 (Plus $199.99) | $29.99 / $59.99 | ~$84–$132 (billed annually) | $35.99 | Free; Premium ~$84–$168 (PWYW) |
| **Platforms** | iOS, Android, Web | iOS, Mac, Web | iOS, Android, Web | Apple only | Apple only | iOS, Android, Web | iOS, Android, Web |
| **Bank sync** | Select banks | Plaid (US only) | Plaid + MX + Finicity | 4 providers, 55 countries | Yodlee (+others) | EU-strong | Plaid |
| **Sync reliability (reviews)** | Mixed | Poor–Mixed | Mixed–Poor | Mixed | Mixed–Poor | Poor | Mixed |
| **Categorization** | Manual + rules | AI (overrides user) | Rules + AI | AI + rules | Rules | Basic auto | Auto |
| **Manual-entry speed** | Medium | Medium | Slow | Slow (dense form) | Slow | **Fast** | Slow |
| **Predictive cashflow** | ❌ (targets only) | ❌ | Basic forecasts | Scheduled-txn forecast | Scheduled-txn forecast | ❌ | ❌ |
| **Receipt OCR** | ❌ | ❌ | ❌ (attachments) | Attachments | Attachments | ❌ | ❌ |
| **On-device AI / privacy** | Cloud | Cloud (privacy-positioned) | Cloud, SOC 2 | E2E claimed | Cloud sync | Cloud | Cloud, upsell model |
| **Learning curve** | **High** | Low | Medium | **High** | **High** | Low | Low |
| **Household** | 6 free | Paid per user | Unlimited | Yes | Limited | Shared wallets | Limited |
| **Israel support** | Manual/import | ❌ (US only) | ❌ (unverified for IL banks) | Unverified for IL banks | Unverified | Unverified | ❌ |

*Sync-reliability ratings are qualitative and based on the cited reviews. They are not measured stats.*

## 1.4 Unmet market needs (the gaps)

1. **Forward-looking intelligence.** Every app answers "where did it go?" None answers well: "Given how *I* behave, will I make it to payday? What happens if I buy this?" Forecasts that exist are just scheduled transactions added up. They don't model behavior.
2. **Sync-independent value.** Aggregator sync breaks across *every* competitor. The product needs to stay fully useful when sync is down or not available, which is the default in Israel, much of the world, and for privacy-conscious users. That means manual entry has to be close to free.
3. **Zero-friction capture.** Manual input is a dense form everywhere except Spendee. Nobody uses the Action button, Lock Screen controls, Live Activities, or the camera-as-input in a real way.
4. **Categorization the user can trust.** Users want AI that *suggests* and *learns from corrections*. They don't want AI that *overrides* them (see the Copilot complaints).
5. **Real privacy.** No competitor offers zero-knowledge, local-first storage *together with* intelligence. Today privacy and smarts trade off against each other.
6. **Emotional and wellbeing layer.** "Am I okay?" is the real question users have, and no app answers it with one honest, explainable signal.
7. **Pricing honesty.** Users are tired of subscriptions: prices revealed after bank linking, trials that need a card, upsells inside paid tiers.
8. **Non-US markets, Israel specifically.** No polished iOS-native app handles Israeli realities: credit-card deferred monthly debit (חיוב דחוי), installment purchases (תשלומים), ILS/USD/EUR multi-currency, Hebrew RTL, and the ISA-licensed open-banking ecosystem.
9. **Performance at scale.** Copilot users report the app is unusable with thousands of transactions. Being native-fast with 50k+ rows is a differentiator in itself.

---

# Phase 2 — Unique Value Proposition (UVP)

**Positioning statement:** *The finance app that sees ahead, so you don't have to look back. Private by construction, fast by obsession.*

The core architectural bet: **all intelligence runs on-device, over a local-first encrypted ledger.** Sync and aggregation make it better. The product doesn't depend on them.

## UVP 1 — "Runway": Behavioral Cash-Flow Simulation

**Problem.** Competitor forecasts only add up scheduled bills (MoneyWiz, Banktivity) or don't exist (Copilot, YNAB, Spendee). Users run out of money in the *variable* spend: groceries, dining, impulse buys. Those are exactly the categories nobody models.

**Mechanism**
- **Deterministic layer.**
  - Detects recurring income and bills (periodicity detection over merchant and amount clusters, tolerant of ±3 days and ±10% amount drift).
  - Models Israeli credit-card deferred settlement dates and installment schedules as first-class objects.
- **Stochastic layer.**
  - Monte Carlo simulation, 1,000–5,000 paths, of daily variable spend per category. Inputs: the user's own empirical distributions with day-of-week and day-of-month seasonality, payday effects (spending spikes right after salary), and a recency-weighted trend.
  - Output: a **fan chart**. The P10/P50/P90 balance from today to the next payday and 90 days out, plus "probability of going below ₪0 / below your safety buffer."
- **What-if sandbox.**
  - "Buy a ₪4,000 laptop in 3 installments?" Drag a chip onto the timeline and the fan updates live in under 100 ms.
  - The Foundation Models framework parses natural-language what-ifs ("what if I cut eating out by a third?") into a structured `Scenario` with `@Generable`. **The numbers always come from the deterministic simulator, never from the LLM.**
- **Explainability.** Every projection has a "why" sheet: "P50 dips on Nov 2 because your Isracard bill (₪6.2k) settles before salary (Nov 10)."

**Why competitors can't easily copy it**
- Their architecture is cloud-dashboard plus aggregator. Running per-user simulations server-side costs money at scale and raises privacy exposure. Running it on-device needs a native, performant local ledger, and most of them have web-first data models (Copilot is fighting performance already).
- Behavioral modeling needs *clean* data. Their categorization trust problems poison the inputs.
- YNAB's methodology deliberately rejects forecasting ("live on last month's income"). Copying this would contradict its brand.

**On-device feasibility: high**
- About 5,000 paths × 90 days × ~15 categories ≈ 6.75M samples. With vectorized `Accelerate`/SIMD or Swift `Float` arrays on a background actor, that's well under a second on A17/A18-class chips. **(Estimate. Benchmark it in the prototype.)**
- Incremental: re-simulate only when a transaction is added, via a debounced background task.
- No LLM is needed for the math. The LLM is optional UX sugar, gated on `SystemLanguageModel.default.availability`.

## UVP 2 — "Snap": On-Device Vision Ingestion for Receipts, Invoices, and Screenshots

**Problem.** Manual entry is clunky everywhere. No competitor in the set has real receipt extraction. They only attach images. In Israel, many expenses (cash, Bit/PayBox transfers, utility invoices, arnona) never hit an aggregator anyway.

**Mechanism**
- Inputs: camera (VisionKit `DataScannerViewController` for live capture, or document camera), Share Sheet extension (PDF invoices from Mail, screenshots of Bit/PayBox confirmations), and Photos.
- Pipeline:
  1. Vision document/text recognition. iOS 26 added structured document reading; iOS 27 lets the Foundation Models framework **call Vision OCR and barcode tools directly and accept multimodal image prompts** ([WWDC26 iOS guide](https://developer.apple.com/wwdc26/guides/ios/)).
  2. Guided generation into a typed `ReceiptExtraction` (merchant, date, total, currency, VAT, line items, installment count).
  3. Deterministic validation: line items should sum to the total, the date shouldn't be in the future, and the currency should match the locale.
  4. Confidence-scored fields. Anything low-confidence is highlighted for a one-tap fix.
- **Dedup and merge.** When a bank or card transaction arrives later, the receipt merges into it (amount ±1%, date ±3 days, merchant fuzzy match), which enriches it with line items. This is how you get line-item-level budgets ("you spent ₪310 on snacks inside supermarket runs").
- **Learning.** User corrections are saved as per-merchant rules and few-shot examples in the local store.

**Why competitors can't easily copy it**
- Cloud OCR (Veryfi, Google, AWS) costs per page and sends receipts off-device, which breaks privacy claims. Apple's on-device stack is free per call, but only an iOS-native, Swift-first codebase can exploit it fully. Cross-platform competitors (YNAB, Monarch, Spendee, Rocket Money) would need a parallel Android pipeline.

**On-device feasibility: high for the common case**
- **Caveat (important for Israel):** Apple Intelligence currently supports English, Danish, Dutch, French, German, Italian, Norwegian, Portuguese, Spanish, Swedish, Turkish, Vietnamese, Chinese, Japanese, and Korean. **Hebrew isn't on the list** ([Apple Newsroom, Sep 2026](https://www.apple.com/newsroom/2026/09/major-updates-for-apples-software-platforms-are-now-available/)). Vision OCR language coverage for Hebrew is **unverified**. Check `supportedRecognitionLanguages` at runtime.
- **Fallback:** Vision OCR plus a deterministic regex/heuristic parser for amounts, dates, and VAT, plus a small custom Core ML / Core AI token classifier trained on Israeli receipts. Server fallback only by explicit opt-in.

## UVP 3 — "Pulse": Financial Stress Index (FSI)

**Problem.** Users don't want 30 reports (MoneyWiz). They want to know whether they're okay. No competitor reduces financial health to one honest, explainable, *leading* indicator.

**Mechanism.** A composite 0–100 score, recomputed on every transaction. The weights below are starting values; tune them with user research:
| Component | Signal | Weight |
|---|---|---|
| **Spending velocity** | 7-day spend rate vs. the user's own 90-day baseline for the same point in the pay cycle (z-score) | 30% |
| **Runway risk** | P(balance < buffer before next income), taken from UVP 1 | 30% |
| **Commitment load** | Fixed + installment obligations ÷ expected income | 20% |
| **Volatility** | Rolling std-dev of daily discretionary spend | 10% |
| **Buffer depth** | Liquid balance ÷ average monthly essential spend | 10% |

- **Presentation:** a single glass "pulse orb" whose tint, motion speed, and haptic signature shift with the score (see Design System). Calm = slow, cool. Elevated = faster, warmer. Never alarm-red, because the design aims to avoid shame.
- **Leading, not lagging.** "Your pace this week is 1.6× your normal for days 8–14 after payday." That fires a *gentle* notification **before** the overspend.
- **Ethics guardrails.** No dark patterns, and the score is always explainable through a tap-through breakdown. The user can turn it off. The score never leaves the device. Microcopy written to avoid shame.

**Why competitors can't easily copy it**
- It needs UVP 1's simulation as an input. Pay-cycle-aligned baselines need clean, deduped, local data.
- Cloud apps that compute a "stress score" on servers create a sensitive inferred-data asset (regulatory and PR risk). On-device avoids that.

**On-device feasibility: trivial.** It's arithmetic over local aggregates. Expose it through an `AppEntity` so Siri can answer "How am I doing financially?"

## UVP 4 — "Vault": Local-First, Zero-Knowledge Sync

**Problem.** Privacy concerns, data-loss horror stories ("Spendee deleted years of data"), and MoneyWiz's password-prompt trust issue. Users have to trust the vendor with their whole financial life.

**Mechanism**
- **Source of truth is on-device.** An encrypted SQLite store (SwiftData/Core Data). The app works fully offline and with no account.
- **Sync goes through the user's own iCloud private database** using `CKSyncEngine`. **The payload is encrypted client-side** with CryptoKit AES-GCM before upload, so Apple's servers and *we* see only ciphertext. The data key lives in the iCloud Keychain (synchronizable, E2E) and is wrapped by a user-held recovery key (24-word or printable QR).
- **No developer backend holds financial data.** The only server is a thin, stateless token broker for aggregator OAuth (see 3b), and it never persists transactions.
- **Export anytime:** CSV/OFX/JSON. Ledger history is append-only, so changes can be undone and "data vanished" is impossible.

**Why competitors can't easily copy it**
- Monarch, Copilot, YNAB, and Rocket Money run server-side categorization and analytics. Their *business and analytics* depend on server-readable data. Retrofitting zero-knowledge storage means rebuilding the backend and giving up server-side features and data-driven upsells.

**On-device feasibility: high.** `CKSyncEngine` (iOS 17+), CryptoKit, and Keychain are mature. The cost is engineering effort: conflict resolution and key recovery UX.

> **Combined moat:** UVP 4 makes UVPs 1–3 *possible without compromise*. They're intelligent *because* the data is local and clean, and private *because* the intelligence is local. Competitors would have to change their architecture, not just add a feature.

---

# Phase 3a — Design System

## Principles
1. **Content first, glass for controls.** Apple's guidance: Liquid Glass belongs on the navigation and control layer, not on content ([Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)).
2. **Calm money.** Neutral by default. Color carries *meaning* (state/risk), never decoration.
3. **Every interaction confirms itself** through visual, haptic, and sometimes audio feedback.
4. **One-hand reachable.** Primary actions sit in the bottom 40% of the screen.

## Material & depth layers (real APIs)

| Layer | Purpose | Implementation (iOS 26/27) |
|---|---|---|
| L0 Content | Transactions, charts | Opaque system backgrounds (`.background`), no glass |
| L1 Chrome | Tab bar, toolbars, nav | System components adopt Liquid Glass automatically when built with the iOS 26+ SDK. **Don't** add custom backgrounds behind them |
| L2 Floating controls | Quick-add FAB, filter chips, Runway scenario chips | `.glassEffect(.regular.interactive(), in: .capsule)` inside a `GlassEffectContainer(spacing:)` for shared sampling and morphing ([Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views); [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)) |
| L3 Transient | Quick-entry sheet, Snap review | Sheets with system glass, morphing from the FAB via `glassEffectID(_:in:)` |
| L4 Signal | Pulse orb | `.glassEffect(.regular.tint(stateColor))` + `MeshGradient` underlay + `TimelineView` animation |

```swift
@Namespace private var glass
GlassEffectContainer(spacing: 24) {
    HStack {
        QuickAddButton()
            .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
            .glassEffectID("add", in: glass)
        if isExpanded {
            CategoryChip(.groceries)
                .glassEffect(.regular.interactive())
                .glassEffectID("groceries", in: glass)
        }
    }
}
```

- **Respect user settings.**
  - iOS 27 adds a user-level Liquid Glass slider from *ultraclear* to *fully tinted* ([Apple Newsroom](https://www.apple.com/newsroom/2026/09/major-updates-for-apples-software-platforms-are-now-available/)). Test both ends.
  - Honor `accessibilityReduceTransparency`, `accessibilityReduceMotion`, and Increase Contrast, falling back to solid tinted fills.
- **"Holographic depth" (🔮 SPECULATIVE / custom).** Not a system API. You'd build it yourself: subtle parallax on the Pulse orb and Runway fan from `CoreMotion` attitude (±4pt max), plus a Metal `ShaderLibrary` `.layerEffect` for specular highlights. Off when Reduce Motion is on. Keep it to one hero surface or it becomes noise.

## Adaptive color palette
- **Base:** system semantic colors (`.primary`, `.secondary`, `.background`), so Dark/Light/Increased Contrast and tinted icon modes all work.
- **Semantic financial tokens** (asset catalog, with light/dark/high-contrast variants):
  - `money.in` (teal-green), `money.out` (neutral ink, *not* red), `risk.calm` / `risk.watch` / `risk.elevated` (blue → amber → coral), `forecast.band` (accent at 18% opacity).
- **Contextual palette:** the app accent subtly tracks the FSI state, interpolated in OKLCH for perceptual smoothness. The tint changes are limited to the Pulse surface and the widget backgrounds.
- **Category colors:** 12 hues, checked for color-blind distinguishability and always paired with SF Symbols. Color is never the only signal.

## Dynamic, contextual typography
- **SF Pro / SF Pro Rounded for numerals** with `.monospacedDigit()`, so balances don't jitter while they animate.
- **Dynamic Type** across the full range, including AX5. Hero numbers use `.font(.system(.largeTitle, design: .rounded, weight: .semibold))` and switch to a stacked layout at accessibility sizes (`@Environment(\.dynamicTypeSize)`, `ViewThatFits`).
- **Contextual weighting:** the balance's weight and size shift with relevance. The hero number scales down when scrolled (`.scrollTransition`), and the "safe-to-spend today" figure gets emphasis on a payday-minus-3 state.
- **Number formatting:** `Decimal` + `FormatStyle.Currency` with locale. ILS shows ₪ with RTL-correct placement. Use `.contentTransition(.numericText(value:))` when values change.
- **Hebrew/RTL:** test layout mirroring end to end, with SF Hebrew fallback. Financial numbers stay LTR inside RTL text (use Unicode isolates).

## Adaptive micro-haptics
| Moment | Haptic | API |
|---|---|---|
| Transaction saved | `.success` | `.sensoryFeedback(.success, trigger: savedCount)` |
| Category chip snap | `.selection` | `.sensoryFeedback(.selection, trigger: category)` |
| Amount keypad digit | `.impact(weight: .light, intensity: 0.5)` | `sensoryFeedback` |
| Runway what-if crosses ₪0 | Custom "soft thud" | Core Haptics `CHHapticPattern` (transient, intensity 0.6, sharpness 0.2) |
| Pulse orb tap | Heartbeat pattern; **tempo scales with FSI** (calm 54 bpm → elevated 90 bpm) | Core Haptics continuous + transient events, parameter curves |
| Budget limit reached | `.warning` | `sensoryFeedback` |

- Stay inside a haptic budget: no more than one notable haptic per user action. Respect the system haptics setting. Haptics are never the only feedback channel.

## Gesture navigation
- **Tab structure** (system Liquid Glass tab bar with scroll-minimize, `.tabBarMinimizeBehavior(.onScrollDown)`): *Today* · *Runway* · *Ledger* · *Search* (role `.search`).
- **Gestures:**
  - Swipe a transaction right to recategorize (chip carousel) and left to split or delete. On iOS 27 you can use swipe actions in any `ScrollView` via `swipeActionsContainer` ([WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/)).
  - Long-press the FAB to bring up a radial category picker.
  - Drag on the Runway fan to scrub the date. Pinch to change horizon (30/90/365 days).
- Every gesture has a visible button equivalent (accessibility and discoverability). Introduce gestures progressively with **TipKit**.

## Widget layouts (WidgetKit)
| Family | Content |
|---|---|
| `systemSmall` | Safe-to-spend today + Pulse ring |
| `systemMedium` | Safe-to-spend + mini Runway fan (P50 line, P10–P90 band) + 3 quick-log buttons (interactive, `Button(intent:)`) |
| `systemLarge` | Runway 30-day + top 3 category paces |
| `accessoryCircular` (Lock Screen) | Pulse gauge |
| `accessoryRectangular` | "₪412 left today · payday in 6d" |
| `accessoryInline` | "Safe: ₪412" |
| **Control** (Control Center / Lock Screen / Action button) | "Quick Log" `ControlWidgetButton` |
| StandBy / Watch Smart Stack | Safe-to-spend, high-contrast |

- Support **accented / tinted rendering modes** (`widgetRenderingMode`, `widgetAccentable()`) and clear glass. iOS 27 adds widget customization through App Intents and dynamic styling ([WWDC26 iOS guide](https://developer.apple.com/wwdc26/guides/ios/)).
- **Privacy:** widgets show redacted placeholders when the device is locked. Use `.privacySensitive()` on balances, plus a user toggle.

---

# Phase 3b — Tech Stack & Architecture

## Platform baseline
- **Minimum deployment: iOS 26.** Covers Liquid Glass and Foundation Models v1. Gate iOS 27 features (multimodal FM prompts, Vision-as-tool, widget App Intent configuration) behind `if #available(iOS 27, *)`.
- **Swift 6 language mode** with strict concurrency. Use `@MainActor` UI, `actor`-isolated services, and `Sendable` domain models.
- **SwiftUI** throughout. Drop to UIKit only for VisionKit camera wrappers if needed.
- **Xcode 27.** Its built-in agent skills for SwiftUI conventions are useful for scaffolding ([WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/)).

## Persistence: SwiftData vs Core Data

| Criterion | SwiftData | Core Data |
|---|---|---|
| Ergonomics / SwiftUI binding | ✅ `@Model`, `@Query` | ⚠️ Verbose |
| Large datasets (50k+ txns), batch ops, aggregate queries (`NSExpression`, group-by) | ⚠️ Weaker | ✅ Mature (`NSBatchInsertRequest`, fetch with `propertiesToGroupBy`) |
| CloudKit auto-sync | ✅ but constrained: no unique constraints, relationships must be optional, additive-only schema in prod ([NativeFirst](https://nativefirstapp.com/learn/field-notes/swiftdata-production-2026-cloudkit-gotchas/); [fatbobman](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/)) | ✅ `NSPersistentCloudKitContainer`, same CloudKit constraints |
| **Client-side encrypted payload sync** | ❌ Not with built-in sync | ❌ Not with built-in sync |
| Swift 6 concurrency | ✅ `@ModelActor` | ⚠️ Manual context discipline |

**Decision**
- Use **SwiftData for the local store** (or Core Data if benchmarks fail; see below). **Turn off its automatic CloudKit sync** and use **`CKSyncEngine` with app-level encrypted records**. That's the only way to get zero-knowledge storage, because built-in mirroring uploads field values the developer can't encrypt client-side.
- Wrap persistence behind a `LedgerRepository` protocol so the engine can be swapped.
- **Spike in week 1:** generate 100k transactions and benchmark category-month aggregates. If SwiftData `#Predicate` plus in-memory reduction goes over 50 ms, use Core Data (or GRDB/SQLite) for the analytics read model.
- **Event-sourced ledger:** an append-only `LedgerEvent` table (create/edit/delete) and materialized `Transaction` views. That makes CRDT-like merges, undo, and "no data loss" guarantees possible.
- **Money type:** `Decimal` with an explicit `currencyCode`. **Never `Double`.** Store minor units (`Int64` agorot/cents) for sums.

## Sync & encryption (Vault)
- `CKSyncEngine` on the private database, custom zone `LedgerZone`. Each record carries `{id, version, vectorClock, ciphertext, nonce, keyID}`.
- **Encryption:**
  - CryptoKit `AES.GCM` with a 256-bit Data Encryption Key (DEK).
  - The DEK is wrapped by a Key Encryption Key derived from the user's recovery phrase (HKDF-SHA256 over a BIP-39-style seed). The wrapped DEK is stored in the **iCloud Keychain** (`kSecAttrSynchronizable`) for seamless multi-device use.
  - **Secure Enclave:** a non-exportable P-256 key protects the *local* DEK cache and signs device enrollment. Note: Secure Enclave keys can't sync, so they're used for per-device wrapping, not as the sync key.
  - App lock: `LocalAuthentication` Face ID, with the Keychain item gated by `.biometryCurrentSet` / `.userPresence`.
  - CloudKit `encryptedValues` adds a defense-in-depth layer for metadata fields.
- **Conflict resolution:** last-writer-wins per field using Hybrid Logical Clocks. Deletions are tombstones. Splits and merges are events.
- **File protection:** `NSFileProtectionComplete` on the store. Exclude caches from backup where needed.

## Intelligence stack
| Need | Tech | Notes |
|---|---|---|
| Structured extraction, NL what-ifs, categorization suggestions | **Foundation Models framework** (`LanguageModelSession`, `@Generable`, `@Guide`, `Tool`) ([Apple](https://developer.apple.com/foundation-models-framework/)) | Check `SystemLanguageModel.default.availability`. Needs an Apple Intelligence device (iPhone 15 Pro / 16+) and a supported language. **Hebrew not supported (Oct 2026)** |
| Multimodal receipt understanding | FM framework on iOS 27: image prompts + Vision OCR/barcode as tools | iOS 27+ only |
| OCR baseline | Vision text/document recognition, VisionKit `DataScannerViewController` | Works on all devices. Verify Hebrew support |
| Custom models (merchant normalization, category classifier, anomaly detection) | **Core ML**, or iOS 27 **Core AI** ([WWDC26](https://developer.apple.com/wwdc26/guides/ios/)) | Train with Create ML or PyTorch → coremltools. Ship a small text classifier (<5 MB) and personalize on-device with per-user rules and a nearest-neighbor layer |
| Simulation | Swift + Accelerate (vDSP) on a background actor | Deterministic, testable, no LLM |
| Optional heavier reasoning | FM on **Private Cloud Compute**: free for Small Business Program apps with <2M first-time downloads ([WWDC26](https://developer.apple.com/wwdc26/guides/ios/)) | Explicit opt-in. Disclose clearly in the privacy UX. Subject to Apple's limits |

```swift
import FoundationModels

@Generable
struct ReceiptExtraction {
    @Guide(description: "Merchant name as printed, without branch number")
    var merchant: String
    @Guide(description: "Grand total including VAT, as a decimal string, e.g. \"128.40\"")
    var total: String
    @Guide(description: "ISO 4217 currency code")
    var currency: String
    @Guide(description: "Number of installments if stated, otherwise 1")
    var installments: Int
}

func extract(from ocrText: String) async throws -> ReceiptExtraction? {
    guard case .available = SystemLanguageModel.default.availability else { return nil } // fall back to heuristic parser
    let session = LanguageModelSession(instructions: "Extract receipt fields. Never guess a total that is not printed.")
    return try await session.respond(to: ocrText, generating: ReceiptExtraction.self).content
}
```

**AI evaluation:** use the iOS 27 **Evaluations framework** ([WWDC26](https://developer.apple.com/wwdc26/guides/ios/)) with a golden set of 500+ anonymized receipts. Track field-level precision and recall per release.

## Bank data: aggregation strategy (tiered, region-aware)

| Region | Option | Status / notes |
|---|---|---|
| 🇺🇸 US / 🇬🇧 UK (Apple Card, Apple Cash, Savings; UK Open Banking via Wallet) | **FinanceKit** | **US and UK only.** UK needs iOS 18.4+ and covers about 13 institutions via Open Banking (Barclays, HSBC, Lloyds, Monzo, Nationwide, NatWest, Santander...). Needs an **organization** developer account and a managed entitlement request ([Apple FinanceKit](https://developer.apple.com/financekit/); [NetTrack](https://blog.nettrack.me/posts/apple-wallet-uk-bank-accounts)). On-device, no server, best for privacy. **Not available in Israel** |
| 🇺🇸 US / 🇨🇦 CA / 18 EU+UK countries | **Plaid** | Countries: US, CA, GB, AT, BE, DE, DK, EE, ES, FI, FR, IE, IT, LV, LT, NL, NO, PL, PT, SE ([Plaid Help](https://support.plaid.com/hc/en-us/articles/27895826947735-What-Plaid-products-are-supported-in-each-country-and-region)). **No Israel.** Per-connection pricing (not published publicly, so **unverified**) |
| 🇪🇺 EU / UK | **Enable Banking** (indie-friendly, free restricted-production tier for self-linked accounts), **Tink**, **Salt Edge** (quote-based) | **GoCardless Bank Account Data (ex-Nordigen) is closed to new signups**. Don't build on it ([Open Banking Tracker](https://www.openbankingtracker.com/guides/free-open-banking-apis)) |
| 🇮🇱 Israel | **Israeli Open Banking** (Bank of Israel standard, Berlin Group-based, [Circular 2658](https://boi.org.il/en/economic-roles/supervision-and-regulation/2527/implementation-of-an-open-banking-standard-in-israel/)) via ISA-licensed aggregators: **Feezback** ([docs](https://docs.feezback.cloud/docs/overview); pricing not public) or **Finanda** ([finanda.com](https://www.finanda.com/en/)) | Under the **Financial Information Service Law 5782-2021**, offering financial-information services generally requires an **ISA licence**: corporate entity, cyber/privacy controls, capital/insurance, fit-and-proper management ([law text](https://israelilegislation.com/laws/financial-information-service-law-2021/p-2/)). **Practical path:** partner with a licensed provider and get legal advice on whether operating on their licence is enough. Budget months for this. |
| Everywhere | **Manual + Snap + CSV/OFX import** (bank and credit-card exports, including Israeli card company Excel exports) | Default, works on day one, zero regulatory surface |

**Architecture for aggregators**
- A `BankDataProvider` protocol with adapters: `FinanceKitProvider` (on-device), `PlaidProvider`, `FeezbackProvider`, `CSVImportProvider`.
- Aggregators need a server for secret keys and webhooks. Run a **stateless token broker** (e.g. Cloudflare Workers or a small Vapor service). It exchanges tokens and relays transactions **end-to-end encrypted to the device's public key** (X25519 + ChaChaPoly via CryptoKit), keeping no plaintext at rest and only short-TTL queues. That keeps the zero-knowledge claim honest. **Document the exact data-flow in the privacy policy.**
- **Sync resilience** (learning from Monarch/Copilot):
  - Per-connection health state machine.
  - Proactive re-auth reminders *before* consent expires (Israel and EU consents expire; PSD2 is commonly 90–180 days).
  - Idempotent transaction IDs plus fuzzy dedup.
  - Never delete local data when sync fails.

## System integrations
- **App Intents** (foundation for Siri, Shortcuts, Spotlight, widgets, controls, Action button):
  - `LogExpenseIntent(amount:category:note:)`, `SafeToSpendIntent`, `RunwayQueryIntent`, `ScanReceiptIntent`.
  - `AppEntity` for Category/Account/Transaction. iOS 27 **entity schemas** feed the Spotlight semantic index, and **View Annotations** let Siri act on on-screen content ([WWDC26 iOS guide](https://developer.apple.com/wwdc26/guides/ios/)). Validate with **AppIntentsTesting**.
  - Note that Siri AI is beta and English-first, and isn't initially available on iOS in the EU ([Apple Newsroom](https://www.apple.com/newsroom/2026/09/major-updates-for-apples-software-platforms-are-now-available/)). Design so intents also work through Shortcuts and controls.
- **WidgetKit + Controls:** see the design system. Share data via an App Group container holding a **read-only, minimal snapshot** (safe-to-spend, FSI, next payday), not the full ledger.
- **Live Activities / Dynamic Island:**
  - "Spending session" (e.g. a trip or a night out) shows a running total vs. allowance, with a quick-add button via `LiveActivityIntent`.
  - "Payday countdown" in the last 3 days of the cycle.
- **TipKit:** progressive disclosure of gestures, Snap, and Runway what-ifs. Rules use `@Parameter` and event donation (e.g. show the "Try Snap" tip after 5 manual entries containing "receipt"-like merchants).
- **Notifications:** local only (computed on-device). Time-sensitive only for real risk (P(below ₪0) > 30%).
- **Watch app (Phase 2):** quick-log complication and Smart Stack safe-to-spend.

## Modular architecture
```
App (composition root, DI container)
├── Features/            (SwiftUI + @Observable view models, one SPM package each)
│   ├── TodayFeature  ├── RunwayFeature  ├── LedgerFeature
│   ├── SnapFeature   ├── OnboardingFeature  └── SettingsFeature
├── Domain/              (pure Swift, no Apple-framework imports; Sendable models, use cases)
│   ├── Money, Transaction, Category, Recurrence, Installment
│   ├── RunwaySimulator, StressIndexCalculator, Categorizer (protocols)
├── Data/
│   ├── LedgerStore (SwiftData/Core Data), SyncEngine (CKSyncEngine), Crypto (CryptoKit/Keychain/SE)
│   ├── Providers: FinanceKit, Plaid, Feezback, CSV
├── Intelligence/        (FoundationModels, Vision, CoreML/CoreAI adapters behind Domain protocols)
├── SystemExtensions/    (Widgets, Controls, LiveActivities, ShareExtension, AppIntents)
└── DesignSystem/        (tokens, glass components, haptics engine, typography)
```
- **Pattern:** unidirectional flow with `@Observable` stores per feature. Use cases are injected via protocols, which keeps it testable. Avoid a heavy framework unless the team prefers TCA. For a solo engineer, plain `@Observable` plus a protocol-oriented domain is faster.
- **Concurrency:** `LedgerActor` (`@ModelActor`) owns writes. `SimulationActor` owns Monte Carlo runs. UI reads snapshots.
- **Performance budgets:**
  - Cold launch to interactive under 400 ms.
  - Ledger scroll at 120 fps with 50k rows (lazy stacks, prefetch).
  - Runway re-sim under 300 ms P95.

## Testing strategy
- **Swift Testing** (`@Test`, parameterized) for the Domain layer. Target 90%+ coverage on money math, recurrence detection, installments, the FSI, and the simulator (seeded RNG for determinism).
- **Property-based tests** for money invariants: splits sum to the total, currency conversions round-trip within tolerance.
- **Snapshot tests** for design-system components across Dynamic Type sizes, RTL, light/dark, and Reduce Transparency.
- **XCUITest** for the critical flows (onboarding, quick-log), plus **AppIntentsTesting** for Siri/Shortcuts paths.
- **AI evaluations:** the Evaluations framework plus a golden receipt set. Track regressions per model or OS update.
- **Sync chaos tests:** two simulated devices with offline edits, conflicting splits, and key rotation.
- **Performance:** XCTest `measure` / Instruments signposts in CI. Fail the build when a budget regresses.
- **Security:** MASVS-aligned checklist, Keychain access-control tests, jailbreak-agnostic (don't rely on detection), and a third-party pentest before handling aggregator data.

---

# Phase 3c — Core User Flows

## Onboarding (target: value in under 90 s, no account required)
1. **Welcome (1 screen):** "See ahead. Stay private." One primary button. No sign-up wall.
2. **Privacy promise (1 screen):** three bullet icons: on-device, your iCloud, encrypted. Link to the data-flow diagram. *Builds trust before any data request.*
3. **Currency & region:** auto-detected from `Locale` (₪ ILS for Israel), with a secondary currency option (USD/EUR).
4. **Pay cycle (the key input):** "When does money usually arrive?" Options: monthly date picker (e.g. the 10th), bi-weekly, or irregular/freelance. Optional amount ("roughly is fine").
5. **Fixed commitments, quick pass:** smart chips for regional defaults (Israel: rent/mortgage, arnona, va'ad bayit, electricity, cellular, car insurance, gan/school). Tap a chip, enter the amount, set the day. Skippable.
6. **Credit-card settlement (Israel-specific):** "Which day does your card bill hit?" (2nd/10th/15th...). This drives deferred-debit modeling.
7. **Data source choice:**
   - (a) Connect (FinanceKit in US/UK; Feezback/Finanda in IL; Plaid/Enable Banking elsewhere).
   - (b) Import a CSV/Excel export.
   - (c) Start manual, which is fully supported. **Pricing is shown *before* any connection.** This is a deliberate contrast with competitor complaints.
8. **Starting balance:** one number.
9. **Instant payoff:** the first Runway fan renders right away from steps 4–8, with a "this gets smarter in ~2 weeks" note. Pulse appears in the "learning" state.
10. **Fast-capture setup (the habit hook):**
    - "Add the Quick Log widget" with an inline preview and deep link to the widget gallery instructions.
    - "Set your Action button" with a guide for Settings → Action Button → Controls → Quick Log.
    - Optional Siri phrase demo.
11. **Optional security:** Face ID lock and creating the recovery key. The recovery key is required before enabling iCloud sync.
12. **TipKit** takes over for progressive feature discovery over the next 7 days.

## Daily logging in under 3 seconds

**Design rule:** the fastest path needs **at most 2 decisions** (amount + confirm). Category, account, date, and currency are *predicted*.

**Smart defaults engine (on-device)**
- **Category prediction** from (time of day, weekday, location cluster if permitted via `CLLocationManager` significant-change/visit monitoring, recent merchant, amount bucket). A simple Naive Bayes / gradient-boosted Core ML model plus per-user frequency tables. It returns the top-3 chips.
- **Account default:** the most-used account for that category.
- **Date:** now. **Currency:** the locale's, or the travel currency if location says the user is abroad.
- **Amount suggestions:** typical amounts for the predicted category ("☕ ₪14").

**Capture surfaces & timing breakdown** (targets/estimates; validate with usability tests):

| Surface | Steps | Est. time |
|---|---|---|
| **Action button → Quick Log control** | Press (0.3 s) → glass sheet with keypad opens over Lock Screen/app (0.4 s) → type "45" (0.9 s) → top predicted chip pre-selected, tap ✓ (0.5 s) → success haptic | **~2.1 s** |
| **Interactive widget (Home)** | Tap a "☕ ₪14" suggestion button (`Button(intent:)`), logged in place with no app launch (0.6 s) | **~0.6–1 s** |
| **Lock Screen / Control Center control** | Swipe/tap control (0.5 s) → keypad (0.4 s) → amount (0.9 s) → ✓ (0.5 s) | **~2.3 s** |
| **Siri / Shortcuts** | "Log 45 shekels groceries" (≈2 s speech) → intent runs in the background, snippet confirms | **~2.5–3 s** (language-dependent; Siri AI is English-first) |
| **In-app FAB** | Tap FAB (0.2 s) → keypad already focused → amount (0.9 s) → ✓ (0.5 s) | **~1.6 s** + launch |
| **Snap receipt** | Open camera via control (0.5 s) → auto-capture when stable (0.8 s) → extraction (≈1–2 s, async, user can leave) → confirm later in the inbox | **~1.3 s user time**, processing in the background |
| **Live Activity (spending session)** | Tap "+" in Dynamic Island → keypad → amount → ✓ | **~2 s** |

**Engineering specs for speed**
- The quick-log intent uses `openAppWhenRun = false` where possible, or `ForegroundContinuableIntent` / a minimal snippet UI. Writes go to the App Group store through a lightweight `QuickLogWriter`, which doesn't need the full ledger or CloudKit up. The main app reconciles the event log on next launch.
- Prewarm: keep the keypad view model tiny and avoid loading the ledger on the quick-log path.
- Undo: a 5-second "Undo" glass toast. Everything is editable later, and the Ledger "Review" inbox collects low-confidence predictions in one batch for weekly cleanup.
- Haptic `.success` + numeric content transition on the Today balance as confirmation.

---

# MVP Roadmap

> Assumes Gabriel as a solo principal engineer, with occasional contract design and legal help. Durations are estimates.

| Phase | Weeks | Scope | Exit criteria |
|---|---|---|---|
| **0. Foundations** | 1–3 | SPM modular skeleton, Domain models (Money/Decimal, Transaction, Recurrence, Installment), SwiftData-vs-Core Data 100k benchmark spike, design tokens + glass components, Swift Testing harness | Benchmark decision made, CI green, perf budgets enforced |
| **1. Private Ledger MVP** | 4–9 | Manual entry, categories + rules, CSV/Excel import (Israeli banks and cards), Today screen, smart defaults v1 (frequency-based), Quick Log intent + Control + interactive widget, Face ID lock, local notifications | Median quick-log ≤3 s in 5-user test, zero data-loss bugs |
| **2. Runway + Pulse** | 10–15 | Recurrence detection, Israeli card deferred-debit + installments, Monte Carlo simulator, fan chart, what-if chips, FSI v1 with explainers, TipKit | Simulator unit-tested with seeded RNG, P95 re-sim <300 ms, users understand the fan (comprehension test) |
| **3. Vault Sync** | 16–20 | CKSyncEngine, client-side encryption, recovery key UX, multi-device conflict tests, export | Chaos tests pass, recovery flow tested by non-technical users |
| **4. Snap** | 21–25 | VisionKit capture, Vision OCR, heuristic parser, FM extraction where available (English receipts), receipt-to-transaction merge, Share Extension | ≥90% total-amount accuracy on golden set (English), Hebrew fallback measured |
| **5. Beta / Launch (IL + US manual-first)** | 26–30 | TestFlight (100–300 users), App Store assets, privacy nutrition label, subscription (StoreKit 2) with honest pricing and a generous free tier | Crash-free sessions ≥99.8%, D30 retention baseline set |
| **6. Connected (post-MVP)** | 31+ | FinanceKit (US/UK, needs org account + entitlement), Feezback/Finanda partnership (IL, legal review), Enable Banking/Plaid (EU/US), stateless E2E token broker, Watch app, Live Activities | Licensing/partner contract signed, sync health dashboard |

**Monetization suggestion (validate):**
- **Free:** manual + widgets + basic Runway.
- **Pro:** about ₪/$ 4–6/mo or ~$40/yr. Includes Snap, full Runway what-ifs, Pulse, and sync.
- **Connected add-on:** priced to cover aggregator per-connection costs.
- Prices go **below** Copilot, Monarch, and YNAB ($95–$109/yr) and are always shown before data linking. These are suggestions, not market data.

---

# Key Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| **Israeli regulatory burden** (Financial Information Service Law, ISA licence for open-banking data) | High | Launch manual/import-first with zero regulatory surface. Partner with a licensed aggregator (Feezback/Finanda). Get Israeli fintech counsel before Phase 6 |
| **Apple Intelligence doesn't support Hebrew; device gating** (iPhone 15 Pro+) | High for IL | Every AI feature has a deterministic fallback (heuristics + Core ML). LLM is an enhancement, never a dependency. Check `availability` at runtime |
| **Aggregator sync fragility** (the industry's #1 complaint) | High | Local-first core value. Connection health machine, proactive re-auth, never delete on failure, multi-provider adapters |
| **Forecast trust**: a wrong prediction hurts credibility | Medium–High | Show uncertainty bands, not single numbers. "Learning" state for the first 2–4 weeks. Explain every projection. Backtest calibration (P10–P90 should contain ~80% of outcomes) |
| **Zero-knowledge key loss** means unrecoverable data | Medium | Mandatory recovery key before sync, iCloud Keychain escrow of the wrapped DEK, local encrypted backups, export reminders |
| **SwiftData maturity / CloudKit schema rigidity** | Medium | Repository abstraction, week-1 benchmark, custom CKSyncEngine (no auto-mirroring), additive-only schema discipline |
| **FinanceKit access** (org account, entitlement approval, US/UK only) | Medium | Treat it as a bonus for US/UK. Register an Israeli company early (also needed for the ISA path) |
| **FSI ethics**: anxiety-inducing, or seen as judgmental | Medium | Language reviewed for shame-avoidance, opt-out, no red alarms, user research with diverse income levels |
| **Solo-dev scope creep** | High | Ship Phases 0–2 as a compelling manual-first product. Snap and Connected follow |
| **Platform churn** (iOS 27 APIs changing; Liquid Glass slider extremes) | Low–Medium | Use system components, `#available` gating, snapshot tests at the glass-slider extremes and Reduce Transparency |
| **Competitor response** (Copilot/Monarch adding forecasting) | Medium | The moat is the *combination*: local-first + on-device AI + Israel/installments specialization + speed. Move fast on niche depth |

---

# Sources
- YNAB pricing: https://www.ynab.com/pricing · Finpresso review (Oct 2026): https://finpresso.com/reviews/ynab-review · Investopedia: https://www.investopedia.com/the-best-budgeting-apps-11725751 · r/ynab: https://www.reddit.com/r/ynab/comments/1r2k0vt/ , https://www.reddit.com/r/ynab/comments/1vxrcq6/ · Trustpilot: https://www.trustpilot.com/review/ynab.com
- Copilot: https://www.copilot.money/ · https://www.copilot.money/faq · FinCompareLab: https://www.fincomparelab.com/reviews/copilot-money-review/ · CashJot coded reviews: https://www.cashjot.com/research/budgeting-app-reviews/coded.csv · r/copilotmoney: https://www.reddit.com/r/copilotmoney/comments/1wcu6gn/
- Monarch: FinCompareLab https://www.fincomparelab.com/reviews/monarch-money-review/ · EnvelopeBudgeting https://envelopebudgeting.com/articles/monarch-money-review · Reddit https://www.reddit.com/r/MonarchMoney/comments/1r4veod/ , /1tln786/ , /1ul6lfh/
- MoneyWiz: https://www.wiz.money/pricing · App Store https://apps.apple.com/us/app/moneywiz-2026-personal-finance/id1511185140 · Setapp reviews https://setapp.com/apps/moneywiz/customer-reviews · The Balance https://www.thebalancemoney.com/a-review-of-moneywiz-2-2386064
- Banktivity: https://www.banktivity.com/content/plans/plans.php · App Store UK reviews https://apps.apple.com/gb/app/banktivity-budget-finances/id1480779512 · Support https://www.banktivity.com/support/articles/app/ibank-for-iphone/
- Spendee: https://www.spendee.com/pricing · Capterra https://www.capterra.com/p/238829/Spendee/reviews/ · Trustpilot https://www.trustpilot.com/review/spendee.com · MakerStack https://makerstack.co/reviews/spendee-review/ · appy.fyi https://appy.fyi/faq/com.cleevio.spendee
- Rocket Money: https://www.rocketmoney.com/learn/personal-finance/how-much-does-rocket-money-cost · CNBC Select https://www.cnbc.com/select/rocket-money-review/ · SaaSSwitcher https://www.saasswitcher.com/blog/rocket-money-reviews
- RiseUp: https://www.riseup.co.il/questions/
- Apple iOS 27 release: https://www.apple.com/newsroom/2026/09/major-updates-for-apples-software-platforms-are-now-available/ · WWDC26 iOS guide https://developer.apple.com/wwdc26/guides/ios/ · WWDC26 SwiftUI guide https://developer.apple.com/wwdc26/guides/swiftui/
- Liquid Glass: https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass · https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views · https://developer.apple.com/documentation/swiftui/glasseffectcontainer
- Foundation Models: https://developer.apple.com/foundation-models-framework/ · Tool calling https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling
- FinanceKit: https://developer.apple.com/financekit/ · NetTrack (UK) https://blog.nettrack.me/posts/apple-wallet-uk-bank-accounts
- Plaid countries: https://support.plaid.com/hc/en-us/articles/27895826947735
- EU aggregators: https://www.openbankingtracker.com/guides/free-open-banking-apis
- Israel: Bank of Israel open banking circular https://boi.org.il/en/economic-roles/supervision-and-regulation/2527/implementation-of-an-open-banking-standard-in-israel/ · Financial Information Service Law https://israelilegislation.com/laws/financial-information-service-law-2021/p-2/ · Feezback https://docs.feezback.cloud/docs/overview · Finanda https://www.finanda.com/en/
- SwiftData: https://nativefirstapp.com/learn/field-notes/swiftdata-production-2026-cloudkit-gotchas/ · https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/

*Third-party review sites and Reddit are qualitative evidence of user sentiment, not representative surveys. Before acting on any price, re-check it on the vendor's page.*
