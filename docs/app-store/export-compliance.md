# Export compliance

Info.plist sets `ITSAppUsesNonExemptEncryption = false` (via pyproject `info."ITSAppUsesNonExemptEncryption"`), so App Store Connect won't ask on every build.

Why "false" is defensible: Fini only uses standard, publicly available algorithms from the OS / `cryptography` (OpenSSL) — AES-GCM, AES Key Wrap, HKDF, scrypt — solely to protect the user's own data at rest and backups, plus OS-provided HTTPS if any. It implements no proprietary algorithms and offers no encryption as a feature to communicate with others. Apple's guidance treats use limited to standard OS-provided crypto / data protection of the app's own data as exempt from documentation upload.

In App Store Connect, if asked: "Does your app use encryption?" → Yes; "qualifies for any exemptions in Category 5, Part 2?" → Yes (standard algorithms, data protection/authentication only). No French declaration needed for exempt use.

Not legal advice — if unsure, read https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations. If you later add end-to-end encrypted sharing between users, revisit (may require a year-end self-classification report to BIS).
