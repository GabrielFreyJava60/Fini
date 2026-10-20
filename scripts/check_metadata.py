"""Check App Store length limits in docs/app-store/metadata.md."""
import pathlib, re, sys
text = (pathlib.Path(__file__).parent.parent / "docs/app-store/metadata.md").read_text()
limits = {"Name": 30, "Subtitle": 30, "Promotional text": 170}
bad = 0
for lang in re.split(r"\n## ", text)[1:]:
    head = lang.splitlines()[0]
    for field, lim in limits.items():
        v = re.search(rf"\*\*{field}:\*\* (.+)", lang).group(1).strip()
        if len(v) > lim: print(f"{head}: {field} {len(v)}>{lim}"); bad = 1
    kw = re.search(r"\*\*Keywords:\*\* (.+)", lang).group(1).strip()
    n = len(kw); print(f"{head}: keywords {n} chars")
    if n > 100: print("  TOO LONG"); bad = 1
    desc = lang.split("**Description:**", 1)[1]
    if len(desc.strip()) > 4000: print(f"{head}: description too long"); bad = 1
sys.exit(bad)
