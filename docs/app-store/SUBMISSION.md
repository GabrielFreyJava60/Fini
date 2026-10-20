# Submitting Fini to the App Store (step by step, on a Mac)

Requirements verified Oct 20, 2026:
- Since **Apr 28, 2026** uploads must be built with **Xcode 26 or later** and an **iOS 26+ SDK** ([Apple](https://developer.apple.com/news/upcoming-requirements/)). Current: Xcode 27.x (needs macOS Tahoe 26.6+). Since Sep 9, 2026 the deployment target must be iOS 13+ (we use 15.0).
- iOS 27 SDK requires the scene-based app life cycle — use the **latest Briefcase and Toga** (BeeWare added Xcode 27 / scene support in Sep 2026).
- Privacy manifest (PrivacyInfo.xcprivacy) required for the app and for "commonly used SDKs" such as OpenSSL. Briefcase's CPython iOS build ships manifests for `_ssl`/`_hashlib`; see step 5 for ours and the `cryptography` caveat.
- App icon 1024×1024 PNG without alpha — `src/finance/resources/icons/fini-1024.png` (regenerate with `python scripts/make_icon.py`).

## 1. Apple Developer Program
Enroll at https://developer.apple.com/programs/ ($99/yr). Individual is fine for a budgeting app (banking/trading/lending apps must be an organization — Fini is none of these). Accept the latest agreements in App Store Connect → Business; for paid apps also fill Paid Apps agreement, tax and banking.

## 2. Bundle ID
Pick the final ID. Briefcase forms it as `<bundle>.<app name>` → currently `com.gabrielfreidlin.finance` (edit `bundle` in pyproject.toml; the app key `finance` is the Python package name — renaming it means renaming `src/finance`). Register it: Certificates, Identifiers & Profiles → Identifiers → + → App IDs → App → explicit Bundle ID. No extra capabilities needed (Keychain needs none).

## 3. Signing
Easiest: Xcode → Settings → Accounts → add Apple ID; use **Automatically manage signing** with your Team. Xcode creates the Apple Distribution certificate and App Store profile at archive time. (Manual alternative: create an Apple Distribution cert + App Store provisioning profile for the App ID.)

## 4. App Store Connect record
My Apps → + → New App: platform iOS, name "Fini: Budget & Cash Flow" (must be unique on the store — have a fallback), primary language English (U.S.), bundle ID from step 2, SKU `ios-fini`, Full access. Then fill from this folder:
- `metadata.md` (EN + add RU and HE localizations), category Finance
- App Privacy → `app-privacy.md`; Privacy Policy URL (publish `docs/privacy-policy.md` with GitHub Pages: repo Settings → Pages → main /docs)
- Age rating → `age-rating.md`; Pricing & availability
- App Review Information → `review-notes.md`

## 5. Build with Briefcase
```bash
python3.12 -m venv .venv && . .venv/bin/activate
pip install -U briefcase
python -m pip install -e ".[test]" && python -m pytest      # sanity
briefcase create iOS
python ios/install_privacy_manifest.py                      # copies PrivacyInfo.xcprivacy
briefcase build iOS
briefcase run iOS -d "iPhone 17 Pro"                        # test on simulator
briefcase open iOS                                          # opens Xcode
```
In Xcode (one time per `create`):
1. Drag `PrivacyInfo.xcprivacy` (from the app folder) into the project navigator, tick the app target → it appears under Build Phases → Copy Bundle Resources.
2. Target → Signing & Capabilities: Team, automatic signing; check Bundle Identifier.
3. Target → General: Version 1.0.0, Build 1 (from pyproject); Supported Destinations: keep iPhone only unless you'll provide iPad screenshots and test iPad.
4. Run on a real iPhone once (Keychain via rubicon-objc and the `cryptography` wheel must be verified on device).

## 6. Archive and upload
Xcode: select "Any iOS Device (arm64)" → Product → Archive → Organizer → **Validate App** → **Distribute App** → App Store Connect → Upload.
(`briefcase package iOS` can also produce the archive/IPA; you can then upload the IPA with **Transporter**.)
After archiving, Organizer → right-click archive → **Generate Privacy Report** and confirm no missing-manifest warnings.
Every new upload needs a higher Build number (`build = "2"` in pyproject, then `briefcase update iOS`).

## 7. TestFlight
Build appears after processing (email). Answer export compliance if prompted (should be skipped thanks to the Info.plist key). Add yourself to internal testing; test onboarding, RU/HE/EN, RTL, backup/restore, kill-and-relaunch persistence. External testers need a short Beta App Review.

## 8. Submit
App Store tab → version 1.0.0 → attach the build → screenshots (`screenshots.md`) → Add for Review → Submit. Choose manual or automatic release. Typical review: 1–3 days.

## App Review risks
- **4.2 Minimum functionality / 4.0 design:** Toga screens look plainer than native apps. Make sure every tab works, has real content, empty states and no placeholder text; no "coming soon" or debug UI. Reviewers reject web-wrapper-like or thin apps.
- **2.1 Completeness:** crashes on launch get instant rejection. The Python runtime + Toga on iOS 27 must be tested on a real device and on the reviewers' likely device (latest iPad if universal). Offline only — test in Airplane Mode.
- **2.5.2 Executable code:** Python is fine as long as all code ships in the bundle; never download/execute scripts. Say so in review notes (done).
- **Finance (3.1, 5.1.1):** no real-money services, so no organization requirement; add "not financial advice" (done). Don't claim bank sync in metadata.
- **ITMS-91061 / 91053 (privacy manifests):** the `cryptography` wheel statically links OpenSSL inside `_rust.abi3.so`; if the upload email reports a missing manifest for that framework, place an OpenSSL `PrivacyInfo.xcprivacy` into `Frameworks/cryptography.hazmat.bindings._rust.framework/` (BeeWare issue Python-Apple-support#268), or replace `cryptography` with Apple CryptoKit via rubicon-objc.
- **Metadata 2.3:** screenshots must show the actual app; names of other apps/brands not in keywords.
- **Name availability:** "Fini" may be taken; keep alternates.
- **Binary size:** bundled Python adds ~40–60 MB — acceptable.
