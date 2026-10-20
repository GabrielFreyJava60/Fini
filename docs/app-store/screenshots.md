# Screenshot spec

Required (Oct 2026): one iPhone set at **6.9"** — 1320×2868 or 1290×2796 portrait (Apple scales down for smaller sizes). If the build supports iPad (Briefcase's default Xcode template is universal), also **13" iPad** 2064×2752 — or restrict to iPhone only in Xcode (Target → General → Supported Destinations) before archiving.
Format: PNG/JPEG, no alpha, RGB. 1–10 per locale; capture on the simulator (`briefcase run iOS -d "iPhone 17 Pro Max"`, then ⌘S) with realistic demo data, no personal data.

| # | Screen | Caption EN | Caption RU | Caption HE |
|---|---|---|---|---|
| 1 | Forecast (Runway range chart) | See your balance until payday | Баланс до зарплаты — заранее | היתרה עד המשכורת, מראש |
| 2 | Pulse score + explanation | Spot spending stress early | Перерасход виден заранее | זהו לחץ הוצאות בזמן |
| 3 | Quick add | Log an expense in seconds | Запись расхода за секунды | רישום הוצאה בשניות |
| 4 | Installments on a card | Installments, split to the agora | Рассрочки до агоры | תשלומים, עד האגורה |
| 5 | Budgets | Budgets at a glance | Бюджеты с первого взгляда | תקציבים במבט אחד |
| 6 | Assistant chat | Ask in Hebrew, Russian or English | Спросите на русском или иврите | שאלו בעברית, רוסית או אנגלית |
| 7 | Settings / recovery phrase | Your data never leaves your iPhone | Данные остаются на iPhone | הנתונים נשארים באייפון |

Use the Hebrew UI for HE screenshots (RTL) and Russian UI for RU. Optional app preview video: 15–30 s, same sizes.
