# App Privacy ("nutrition label") answers — App Store Connect

**Do you or your third-party partners collect data from this app?** → **No, we do not collect data from this app.**

Result shown on the product page: **Data Not Collected**.

Rationale (Apple's definition: "collect" = transmitting data off the device in a way that lets you or partners access it beyond real-time servicing of the request):
- All data stays in local SQLite storage + Keychain; there is no backend.
- No analytics, ads, crash reporting or third-party SDKs that transmit data.
- User-initiated encrypted export goes where the user chooses; we never receive it.

Tracking: **No** (no IDFA, no ATT prompt, `NSPrivacyTracking = false` in PrivacyInfo.xcprivacy).

Re-check this answer if you ever add: bank sync, crash reporting (e.g., Sentry), analytics, cloud sync to your own server, or remote AI.
