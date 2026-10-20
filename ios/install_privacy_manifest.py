#!/usr/bin/env python3
"""Copy ios/PrivacyInfo.xcprivacy into the Briefcase-generated Xcode app bundle sources.

Briefcase has no config option for an app-level privacy manifest. Run this after
`briefcase create iOS` (and after any re-create). Then, once, in Xcode
(`briefcase open iOS`), make sure PrivacyInfo.xcprivacy is in the app target's
"Copy Bundle Resources" phase (drag it into the project navigator, tick the app target).
Verify after archiving: Organizer -> right-click archive -> Generate Privacy Report.
"""
import pathlib, shutil, sys

root = pathlib.Path(__file__).resolve().parent.parent
src = root / "ios" / "PrivacyInfo.xcprivacy"
xcode = root / "build" / "finance" / "ios" / "xcode"
if not xcode.is_dir():
    sys.exit("Run `briefcase create iOS` first (expected build/finance/ios/xcode).")
targets = [p for p in xcode.iterdir() if p.is_dir() and (p / "Info.plist").exists()]
if not targets:
    targets = [xcode / "Fini"]
for t in targets:
    t.mkdir(exist_ok=True)
    shutil.copy2(src, t / "PrivacyInfo.xcprivacy")
    print("copied ->", t / "PrivacyInfo.xcprivacy")
