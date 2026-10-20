> **Archived:** this Swift implementation is kept for history only; active development continues in the Python/BeeWare version at the repository root.

# FinanceApp — project skeleton & data model

```bash
# On a Mac (Xcode 27, iOS 26+ SDK):
brew install xcodegen && xcodegen generate && open FinanceApp.xcodeproj

# Pure-domain tests (macOS or Linux, Swift 6.x):
for p in CoreModels Runway Pulse Snap; do (cd Packages/$p && swift test); done
```
See ARCHITECTURE.md.
